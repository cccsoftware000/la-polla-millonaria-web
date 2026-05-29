const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();

// ==================== CONFIGURACIÓN ====================
const MIN_EXACT_HITS_TO_WIN = 4;

// API Key desde variable de entorno
const API_FOOTBALL_KEY = process.env.API_FOOTBALL_KEY || '';

// Contador para límite diario (en memoria)
let dailyRequestCount = 0;
const DAILY_LIMIT = 90;

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
                await admin.firestore().collection('pollas').doc(pollaDoc.id).update({
                    'status': 'CLOSED',
                    'closedAt': now,
                    'closedReason': 'Primer partido iniciado',
                });
                closedCount++;
                console.log(`🔒 Polla cerrada: ${pollaDoc.id}`);
            }
        }
        console.log(`🔒 ${closedCount} pollas cerradas`);
    }
);

// ==================== 4. ACTUALIZAR RESULTADOS AUTOMÁTICOS ====================
exports.updateMatchResults = onSchedule(
    {
        schedule: '0 1,7,13,19 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        console.log('🔄 Actualizando resultados de partidos...');

        const apiKey = API_FOOTBALL_KEY;

        if (!apiKey) {
            console.log('❌ API Key no configurada');
            return;
        }

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);

        const matchesToUpdate = await admin.firestore()
            .collection('matches')
            .where('realHomeScore', '==', null)
            .where('dateTime', '>=', yesterday)
            .get();

        if (matchesToUpdate.empty) {
            console.log('📭 No hay partidos pendientes');
            return;
        }

        let updatedCount = 0;
        for (const matchDoc of matchesToUpdate.docs) {
            const match = matchDoc.data();
            const apiFixtureId = match.apiFixtureId;

            if (!apiFixtureId) continue;

            try {
                const response = await fetch(
                    `https://v3.football.api-sports.io/fixtures?id=${apiFixtureId}`,
                    {
                        headers: {
                            'x-rapidapi-key': apiKey,
                            'x-rapidapi-host': 'v3.football.api-sports.io',
                        },
                    }
                );

                const data = await response.json();
                const fixture = data.response?.[0];

                if (fixture?.fixture?.status?.short === 'FT') {
                    await matchDoc.ref.update({
                        realHomeScore: fixture.goals.home,
                        realAwayScore: fixture.goals.away,
                        status: 'FINISHED',
                    });
                    updatedCount++;
                    console.log(`✅ ${match.local} ${fixture.goals.home} - ${fixture.goals.away} ${match.visitor}`);
                }

                await new Promise(resolve => setTimeout(resolve, 1000));
            } catch (e) {
                console.log(`❌ Error: ${match.local} - ${e.message}`);
            }
        }
        console.log(`✅ ${updatedCount} partidos actualizados`);
    }
);

// ==================== 5. CONFIRMAR PAGO ====================
exports.onBetPaid = onDocumentUpdated(
    {
        document: 'bets/{betId}',
        region: 'us-central1',
    },
    async (event) => {
        const before = event.data.before.data();
        const after = event.data.after.data();

        if (before.paymentConfirmed !== true && after.paymentConfirmed === true) {
            console.log(`💰 Procesando pago: ${event.params.betId}`);

            const pollaDoc = await admin.firestore()
                .collection('pollas')
                .doc(after.pollaId)
                .get();

            if (!pollaDoc.exists || pollaDoc.data()?.status !== 'ACTIVE') {
                await event.data.after.ref.update({
                    'status': 'CANCELLED',
                    'cancelledReason': 'Polla cerrada',
                });
                return;
            }

            await admin.firestore().collection('users').doc(bet.uid).update({
              'totalBetsPaid': admin.firestore.FieldValue.increment(1),
              'experiencePoints': admin.firestore.FieldValue.increment(50),
            });

            const settingsDoc = await admin.firestore().doc('settings/global').get();
            let settings = settingsDoc.data();
            if (!settings) {
                settings = { betPrice: 5000, accumulatedPercentage: 60, currentAccumulated: 100000 };
                await admin.firestore().doc('settings/global').set(settings);
            }

            const increment = Math.floor(settings.betPrice * settings.accumulatedPercentage / 100);
            const newAccumulated = settings.currentAccumulated + increment;

            await admin.firestore().doc('settings/global').update({
                'currentAccumulated': newAccumulated,
                'lastAccumulatedIncrease': increment,
            });

            await admin.firestore().collection('accumulated_history').add({
                'betId': event.params.betId,
                'pollaId': after.pollaId,
                'increment': increment,
            });

            await event.data.after.ref.update({ 'status': 'ACTIVE' });
            console.log(`💰 Acumulado: +${increment}`);
        }
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

// ==================== 7. API-FOOTBALL PROXY FUNCTIONS (SEGURAS) ====================

// Resetear contador diario
exports.resetDailyCounter = onSchedule(
    {
        schedule: '0 0 * * *',
        timeZone: 'America/Bogota',
        region: 'us-central1',
    },
    async () => {
        dailyRequestCount = 0;
        console.log('🔄 Contador de API resetado a 0');
    }
);

// Obtener resultados en vivo
exports.getLiveFixtures = onRequest(
    {
        cors: true,
        region: 'us-central1',
    },
    async (req, res) => {
        if (dailyRequestCount >= DAILY_LIMIT) {
            console.warn('⚠️ Límite diario de API alcanzado');
            res.status(429).json({ error: 'Límite de peticiones alcanzado. Intenta más tarde.' });
            return;
        }

        dailyRequestCount++;

        try {
            const apiKey = process.env.API_FOOTBALL_KEY;

            if (!apiKey) {
                console.error('❌ API_FOOTBALL_KEY no configurada');
                res.status(500).json({ error: 'API key no configurada' });
                return;
            }

            const response = await fetch('https://v3.football.api-sports.io/fixtures?live=all', {
                headers: {
                    'x-rapidapi-key': apiKey,
                    'x-rapidapi-host': 'v3.football.api-sports.io',
                },
            });

            const data = await response.json();
            res.status(200).json(data);
        } catch (error) {
            console.error('Error en getLiveFixtures:', error);
            res.status(500).json({ error: error.message });
        }
    }
);

// Obtener resultado de un fixture específico
exports.getFixtureById = onRequest(
    {
        cors: true,
        region: 'us-central1',
    },
    async (req, res) => {
        if (dailyRequestCount >= DAILY_LIMIT) {
            res.status(429).json({ error: 'Límite de peticiones alcanzado' });
            return;
        }

        dailyRequestCount++;

        try {
            const { fixtureId } = req.query;

            if (!fixtureId) {
                res.status(400).json({ error: 'fixtureId es requerido' });
                return;
            }

            const apiKey = process.env.API_FOOTBALL_KEY;

            if (!apiKey) {
                res.status(500).json({ error: 'API key no configurada' });
                return;
            }

            const response = await fetch(`https://v3.football.api-sports.io/fixtures?id=${fixtureId}`, {
                headers: {
                    'x-rapidapi-key': apiKey,
                    'x-rapidapi-host': 'v3.football.api-sports.io',
                },
            });

            const data = await response.json();
            res.status(200).json(data);
        } catch (error) {
            console.error('Error en getFixtureById:', error);
            res.status(500).json({ error: error.message });
        }
    }
);

// Obtener partidos por fecha
exports.getFixturesByDate = onRequest(
    {
        cors: true,
        region: 'us-central1',
    },
    async (req, res) => {
        if (dailyRequestCount >= DAILY_LIMIT) {
            res.status(429).json({ error: 'Límite de peticiones alcanzado' });
            return;
        }

        dailyRequestCount++;

        try {
            const { date } = req.query;

            if (!date) {
                res.status(400).json({ error: 'date es requerido (YYYY-MM-DD)' });
                return;
            }

            const apiKey = process.env.API_FOOTBALL_KEY;

            if (!apiKey) {
                res.status(500).json({ error: 'API key no configurada' });
                return;
            }

            const response = await fetch(`https://v3.football.api-sports.io/fixtures?date=${date}`, {
                headers: {
                    'x-rapidapi-key': apiKey,
                    'x-rapidapi-host': 'v3.football.api-sports.io',
                },
            });

            const data = await response.json();
            res.status(200).json(data);
        } catch (error) {
            console.error('Error en getFixturesByDate:', error);
            res.status(500).json({ error: error.message });
        }
    }
);

// Obtener información de un equipo
exports.getTeamInfo = onRequest(
    {
        cors: true,
        region: 'us-central1',
    },
    async (req, res) => {
        if (dailyRequestCount >= DAILY_LIMIT) {
            res.status(429).json({ error: 'Límite de peticiones alcanzado' });
            return;
        }

        dailyRequestCount++;

        try {
            const { teamId } = req.query;

            if (!teamId) {
                res.status(400).json({ error: 'teamId es requerido' });
                return;
            }

            const apiKey = process.env.API_FOOTBALL_KEY;

            if (!apiKey) {
                res.status(500).json({ error: 'API key no configurada' });
                return;
            }

            const response = await fetch(`https://v3.football.api-sports.io/teams?id=${teamId}`, {
                headers: {
                    'x-rapidapi-key': apiKey,
                    'x-rapidapi-host': 'v3.football.api-sports.io',
                },
            });

            const data = await response.json();
            res.status(200).json(data);
        } catch (error) {
            console.error('Error en getTeamInfo:', error);
            res.status(500).json({ error: error.message });
        }
    }
);

// ==================== PROCESAR POLLA (AUXILIAR) ====================
async function processPolla(pollaId) {
    console.log(`📊 Procesando polla: ${pollaId}`);

    const matchesSnapshot = await admin.firestore()
        .collection('matches')
        .where('pollaId', '==', pollaId)
        .get();

    const results = {};
    matchesSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        if (data.realHomeScore !== undefined && data.realAwayScore !== undefined) {
            results[doc.id] = { home: data.realHomeScore, away: data.realAwayScore };
        }
    });

    const betsSnapshot = await admin.firestore()
        .collection('bets')
        .where('pollaId', '==', pollaId)
        .where('status', '==', 'ACTIVE')
        .where('deleted', '==', false)
        .get();

    if (betsSnapshot.empty) {
        await admin.firestore().collection('pollas').doc(pollaId).update({
            'status': 'FINISHED',
            'processedAt': admin.firestore.FieldValue.serverTimestamp(),
            'winnerCount': 0,
        });
        return;
    }

    const betUpdates = [];
    for (const betDoc of betsSnapshot.docs) {
        const bet = betDoc.data();
        let exactHits = 0;
        for (let i = 0; i < bet.predictions.length; i++) {
            const matchId = bet.predictions[i].matchId;
            const userHome = bet.predictions[i].homeScore;
            const userAway = bet.predictions[i].awayScore;
            const realResult = results[matchId];
            if (realResult && userHome === realResult.home && userAway === realResult.away) {
                exactHits++;
            }
        }
        betUpdates.push({ ref: betDoc.ref, exactHits });
    }

    const batch = admin.firestore().batch();
    for (const update of betUpdates) {
        batch.update(update.ref, { exactHits: update.exactHits });
    }
    await batch.commit();

    let maxHits = 0;
    for (const update of betUpdates) {
        if (update.exactHits >= MIN_EXACT_HITS_TO_WIN && update.exactHits > maxHits) {
            maxHits = update.exactHits;
        }
    }

    if (maxHits === 0) {
        await admin.firestore().collection('pollas').doc(pollaId).update({
            'status': 'FINISHED',
            'processedAt': admin.firestore.FieldValue.serverTimestamp(),
            'winnerCount': 0,
        });
        return;
    }

    const winners = betUpdates.filter(u => u.exactHits === maxHits);
    const winnerCount = winners.length;
    const settingsDoc = await admin.firestore().doc('settings/global').get();
    const currentAccumulated = settingsDoc.data()?.currentAccumulated || 100000;
    const winnerPrize = Math.floor(currentAccumulated / winnerCount);
    const remainingAccumulated = currentAccumulated - winnerPrize;

    const winnerBatch = admin.firestore().batch();
    for (const winner of winners) {
        winnerBatch.update(winner.ref, { status: 'WINNER', prize: winnerPrize });
    }
    for (const update of betUpdates) {
        if (update.exactHits !== maxHits) {
            winnerBatch.update(update.ref, { status: 'COMPLETED' });
        }
    }
    await winnerBatch.commit();

    await admin.firestore().collection('pollas').doc(pollaId).update({
        'status': 'FINISHED',
        'processedAt': admin.firestore.FieldValue.serverTimestamp(),
        'winnerCount': winnerCount,
        'winnerPrize': winnerPrize,
        'winnerIds': winners.map(w => w.ref.id).toList(),
        'maxExactHits': maxHits,
    });

    await admin.firestore().doc('settings/global').update({
        'currentAccumulated': remainingAccumulated,
        'lastWinnerPrize': winnerPrize,
        'lastWinnerCount': winnerCount,
    });

    console.log(`🏆 ${winnerCount} ganadores con ${maxHits} aciertos. Premio: ${winnerPrize} c/u`);
}
