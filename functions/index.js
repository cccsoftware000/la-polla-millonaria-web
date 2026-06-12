const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

// ==================== CONFIGURACIÓN ====================
const MIN_EXACT_HITS_TO_WIN = 4;

// Moneda mas baja en COP (para redondeos de premio)
const COP_MIN_UNIT = 50;

// Nota: Se removieron funciones/servicios de API-Football del backend.

// ==================== 1. CIERRE AUTOMÁTICO DE POLLAS EXPIRADAS ====================
exports.closeExpiredPollas = onSchedule(
    {
        schedule: '0 */6 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        const now = admin.firestore.Timestamp.now();
        const expiredPollas = await admin.firestore()
            .collection('pollas')
            .where('status', '==', 'ACTIVE')
            .where('endDate', '<', now)
            .get();

        const batch = admin.firestore().batch();
        let count = 0;
        for (const doc of expiredPollas.docs) {
            batch.update(doc.ref, {
                'status': 'CLOSED',
                'closedAt': now,
                'closedReason': 'Fecha límite alcanzada',
            });
            count++;
        }
        await batch.commit();
        console.log(`🔒 ${count} pollas cerradas por fecha límite`);
    }
);

// ==================== 3. VERIFICAR CIERRE POR PRIMER PARTIDO ====================
exports.checkFirstMatchStart = onSchedule(
    {
        schedule: '0 */6 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        const now = admin.firestore.Timestamp.now();
        const activePollas = await admin.firestore()
            .collection('pollas')
            .where('status', '==', 'ACTIVE')
            .get();

        let closedCount = 0;
        for (const pollaDoc of activePollas.docs) {
            const matches = await admin.firestore()
                .collection('matches')
                .where('pollaId', '==', pollaDoc.id)
                .get();

            if (matches.empty) continue;

            let firstMatchDate = null;
            matches.docs.forEach((doc) => {
                const matchDate = doc.data().dateTime;
                if (!firstMatchDate || matchDate.toDate() < firstMatchDate.toDate()) {
                    firstMatchDate = matchDate;
                }
            });

            if (firstMatchDate && firstMatchDate.toDate() <= now.toDate()) {
                const pollaRef = admin.firestore().collection('pollas').doc(pollaDoc.id);

                // Cerrar la polla para apuestas
                await pollaRef.update({
                    status: 'CLOSED',
                    closedAt: now,
                    closedReason: 'Primer partido iniciado',
                });

                // Marcar apuestas pendientes como abandonadas
                const pendingBets = await admin.firestore()
                    .collection('bets')
                    .where('pollaId', '==', pollaDoc.id)
                    .where('status', '==', 'PENDING_PAYMENT')
                    .where('deleted', '==', false)
                    .limit(450)
                    .get();

                if (!pendingBets.empty) {
                    const batch = admin.firestore().batch();
                    for (const betDoc of pendingBets.docs) {
                        batch.update(betDoc.ref, {
                            status: 'CANCELLED',
                            cancelledReason: 'Abandonada: inició el primer partido',
                            cancelledAt: now,
                        });
                    }
                    await batch.commit();
                    console.log(`🗑️ ${pendingBets.size} apuestas abandonadas en ${pollaDoc.id}`);
                }

                closedCount++;
                console.log(`🔒 Polla cerrada: ${pollaDoc.id}`);
            }
        }
        console.log(`🔒 ${closedCount} pollas cerradas`);
    }
);

// ==================== 5. CONFIRMAR PAGO ====================
exports.onBetPaid = onDocumentUpdated(
    {
        document: 'bets/{betId}',
        region: 'southamerica-east1',
        serviceAccount: 'la-polla-millonaria@appspot.gserviceaccount.com',
    },
    async (event) => {
        const before = event.data.before.data();
        const after = event.data.after.data();

        // Solo procesar la transicion false -> true
        if (before.paymentConfirmed === true || after.paymentConfirmed !== true) {
            return;
        }

        console.log(`💰 Procesando pago: ${event.params.betId}`);

        const betRef = event.data.after.ref;
        const pollaRef = admin.firestore().collection('pollas').doc(after.pollaId);
        const settingsRef = admin.firestore().doc('settings/global');
        const userRef = admin.firestore().collection('users').doc(after.uid);
        const historyRef = admin.firestore().collection('accumulated_history').doc();

        await admin.firestore().runTransaction(async (tx) => {
            const [pollaSnap, settingsSnap] = await Promise.all([
                tx.get(pollaRef),
                tx.get(settingsRef),
            ]);

            if (!pollaSnap.exists) {
                tx.update(betRef, {
                    status: 'CANCELLED',
                    cancelledReason: 'Polla no existe',
                    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                return;
            }

            const polla = pollaSnap.data() || {};
            const pollaIsOpenForBets = polla.status === 'ACTIVE' && !polla.closedAt;

            // Si ya arranco el primer partido (polla cerrada para apostar), la apuesta se considera abandonada.
            if (!pollaIsOpenForBets) {
                tx.update(betRef, {
                    status: 'CANCELLED',
                    cancelledReason: 'Abandonada: inició el primer partido',
                    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                return;
            }

            const settings = settingsSnap.exists ? (settingsSnap.data() || {}) : {};
            const betPrice = typeof settings.betPrice === 'number' ? settings.betPrice : 5000;
            const accumulatedPercentage = typeof settings.accumulatedPercentage === 'number' ? settings.accumulatedPercentage : 60;
            const basePot = typeof settings.basePot === 'number' ? settings.basePot : 100000;
            const pendingCarry = typeof settings.pendingCarry === 'number' ? settings.pendingCarry : 0;

            // Si no existe settings/global lo inicializamos con defaults.
            if (!settingsSnap.exists) {
                tx.set(settingsRef, {
                    betPrice,
                    accumulatedPercentage,
                    basePot,
                    pendingCarry: 0,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } else {
                // Asegurar campos nuevos sin pisar configuracion existente.
                const patch = {};
                if (settings.basePot === undefined) patch.basePot = basePot;
                if (settings.pendingCarry === undefined) patch.pendingCarry = pendingCarry;
                if (Object.keys(patch).length) {
                    patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
                    tx.update(settingsRef, patch);
                }
            }

            const increment = Math.floor((betPrice * accumulatedPercentage) / 100);

            const previousPrize = typeof polla.prizeAmount === 'number' ? polla.prizeAmount : basePot;
            let newPrize = previousPrize + increment;

            // Si hay carry vivo sin asignar, se aplica a la proxima polla abierta a apuestas en el primer pago.
            if (pendingCarry > 0) {
                newPrize += pendingCarry;
                tx.update(settingsRef, {
                    pendingCarry: 0,
                    pendingCarryAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            tx.update(pollaRef, {
                prizeAmount: newPrize,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            tx.set(historyRef, {
                betId: event.params.betId,
                pollaId: after.pollaId,
                increment,
                previousAccumulated: previousPrize,
                newAccumulated: newPrize,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });

            tx.update(userRef, {
                totalBetsPaid: admin.firestore.FieldValue.increment(1),
                experiencePoints: admin.firestore.FieldValue.increment(50),
            });

            // Asegurar estado ACTIVE (idempotente)
            tx.update(betRef, { status: 'ACTIVE' });
        });

        console.log('💰 Pago procesado y pozo actualizado');
    }
);

// ==================== 6. LIMPIEZAS ====================
exports.cleanDeletedBets = onSchedule(
    {
        schedule: '0 2 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const deletedBets = await admin.firestore()
            .collection('bets')
            .where('deleted', '==', true)
            .where('deletedAt', '<', thirtyDaysAgo)
            .limit(500)
            .get();

        if (deletedBets.empty) {
            console.log('🧹 No hay apuestas para limpiar');
            return;
        }

        const batch = admin.firestore().batch();
        let count = 0;
        deletedBets.docs.forEach((doc) => {
            batch.delete(doc.ref);
            count++;
        });
        await batch.commit();
        console.log(`🧹 Limpiadas ${count} apuestas`);
    }
);

exports.cleanOldAccumulatedHistory = onSchedule(
    {
        schedule: '0 3 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const oldHistory = await admin.firestore()
            .collection('accumulated_history')
            .where('timestamp', '<', thirtyDaysAgo)
            .limit(500)
            .get();

        if (oldHistory.empty) return;

        const batch = admin.firestore().batch();
        let count = 0;
        oldHistory.docs.forEach((doc) => {
            batch.delete(doc.ref);
            count++;
        });
        await batch.commit();
        console.log(`🧹 Limpiados ${count} registros`);
    }
);

// Nota: Se removieron las funciones HTTP/proxy de API-Football del backend.
