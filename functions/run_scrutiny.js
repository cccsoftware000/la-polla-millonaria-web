// scripts/run_scrutiny.js

// ─── CLI argument parsing (antes de inicializar Firebase) ───────────
const args = process.argv.slice(2);
const FLAGS = {
  pollaId: null,
  force: false,
  help: false,
};

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--polla':
    case '-p':
      FLAGS.pollaId = args[++i];
      break;
    case '--force':
    case '-f':
      FLAGS.force = true;
      break;
    case '--help':
    case '-h':
      FLAGS.help = true;
      break;
  }
}

if (FLAGS.help) {
  console.log(`
Uso: node run_scrutiny.js [opciones]

Opciones:
  --polla, -p <id>   Procesar solo una jornada específica (ej: jornada_2)
  --force, -f        Reprocesar aunque ya tenga processedAt
  --help, -h         Mostrar esta ayuda

Sin argumentos: procesa todas las jornadas CLOSED/FINISHED pendientes.

Ejemplos:
  node run_scrutiny.js
  node run_scrutiny.js --polla jornada_2
  node run_scrutiny.js --polla jornada_2 --force
`);
  process.exit(0);
}

const admin = require('firebase-admin');
const serviceAccount = require('../scripts/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const MIN_EXACT_HITS_TO_WIN = 4;
const COP_MIN_UNIT = 50;

// ─── Main ───────────────────────────────────────────────────────────
async function main() {

  if (FLAGS.pollaId) {
    console.log(`📊 Escrutinio para jornada específica: ${FLAGS.pollaId}\n`);
    await processPolla(FLAGS.pollaId, FLAGS.force);
  } else {
    console.log('📊 Iniciando escrutinio general...\n');
    await runScrutiny();
  }

  console.log('\n✅ Escrutinio completado');
}

async function runScrutiny() {
  const allClosed = await db.collection('pollas')
    .where('status', 'in', ['CLOSED', 'FINISHED'])
    .get();

  const pollasPendientes = allClosed.docs.filter(doc => {
    const d = doc.data();
    return d.processedAt == null || d.processedAt === undefined;
  });

  if (pollasPendientes.length === 0) {
    console.log('📭 No hay pollas pendientes de escrutinio');
    return;
  }

  console.log(`📊 Encontradas ${pollasPendientes.length} pollas para procesar\n`);

  for (const pollaDoc of pollasPendientes) {
    await processPolla(pollaDoc.id);
  }
}

// ─── processPolla ───────────────────────────────────────────────────
async function processPolla(pollaId, force = false) {
  console.log(`📊 Procesando polla: ${pollaId}`);

  const pollaRef = db.collection('pollas').doc(pollaId);
  const pollaDoc = await pollaRef.get();

  if (!pollaDoc.exists) {
    console.log('   ❌ Polla no encontrada');
    return;
  }

  const pollaData = pollaDoc.data();

  // Saltar si ya fue procesada (a menos que sea force)
  if (!force && pollaData.processedAt != null) {
    console.log(`   ⏭️  Ya procesada en ${pollaData.processedAt.toDate?.()?.toISOString() ?? pollaData.processedAt}. Usa --force para reprocesar.`);
    return;
  }

  if (force && pollaData.processedAt != null) {
    console.log('   ⚠️  Forzando reprocesamiento...');
  }

  // Verificar que tenga resultados cargados
  const matchesSnapshot = await db.collection('matches')
    .where('pollaId', '==', pollaId)
    .get();

  const results = {};
  matchesSnapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.realHomeScore !== undefined && data.realAwayScore !== undefined) {
      results[doc.id] = {
        home: data.realHomeScore,
        away: data.realAwayScore
      };
    }
  });

  const totalMatches = matchesSnapshot.size;
  const totalWithResults = Object.keys(results).length;

  console.log(`   📋 Partidos: ${totalWithResults}/${totalMatches} con resultados`);

  if (totalWithResults === 0 && totalMatches > 0) {
    console.log('   ❌ No hay resultados cargados. No se puede ejecutar escrutinio.');
    return;
  }

  if (totalMatches === 0) {
    console.log('   ❌ No hay partidos configurados para esta jornada.');
    return;
  }

  // 2. Cancelar apuestas PENDING_PAYMENT
  const pendingBetsSnapshot = await db.collection('bets')
    .where('pollaId', '==', pollaId)
    .where('status', '==', 'PENDING_PAYMENT')
    .where('deleted', '==', false)
    .get();

  if (!pendingBetsSnapshot.empty) {
    const cancelBatch = db.batch();
    for (const doc of pendingBetsSnapshot.docs) {
      cancelBatch.update(doc.ref, {
        status: 'CANCELLED',
        cancelledReason: 'Jornada finalizada sin pago',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await cancelBatch.commit();
    console.log(`   🗑️ ${pendingBetsSnapshot.size} apuestas pendientes canceladas`);
  }

  // 3. Obtener apuestas activas
  const betsSnapshot = await db.collection('bets')
    .where('pollaId', '==', pollaId)
    .where('status', '==', 'ACTIVE')
    .where('deleted', '==', false)
    .get();

  if (betsSnapshot.empty) {
    console.log('   📭 No hay apuestas activas');
    const settingsDoc = await db.doc('settings/global').get();
    const basePot = settingsDoc.data()?.basePot ?? 100000;
    const pot = pollaData?.prizeAmount ?? basePot;
    if (pot > 0) {
      await handleRollover({
        sourcePollaRef: pollaRef,
        sourcePollaId: pollaId,
        reason: 'No hubo apuestas activas',
      });
    }
    await pollaRef.update({
      status: 'FINISHED',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      winnerCount: 0
    });
    return;
  }

  console.log(`   📊 Apuestas activas: ${betsSnapshot.size}`);

  // 4. Calcular aciertos
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

    betUpdates.push({
      ref: betDoc.ref,
      exactHits: exactHits,
      betId: betDoc.id.substring(0, 8)
    });

    console.log(`      ${betDoc.id.substring(0, 8)}: ${exactHits} aciertos`);
  }

  // 5. Guardar aciertos
  const batch = db.batch();
  for (const update of betUpdates) {
    batch.update(update.ref, { exactHits: update.exactHits });
  }
  await batch.commit();

  // 6. Encontrar máximo de aciertos (>= 4)
  let maxHits = 0;
  for (const update of betUpdates) {
    if (update.exactHits >= MIN_EXACT_HITS_TO_WIN && update.exactHits > maxHits) {
      maxHits = update.exactHits;
    }
  }

  console.log(`\n   🏆 Máximo de aciertos: ${maxHits}`);

  const winners = betUpdates.filter(u => u.exactHits === maxHits);
  const winnerCount = winners.length;

  if (maxHits === 0 || winners.length === 0) {
    console.log('   ❌ No hubo ganadores (nadie alcanzó 4 aciertos o más)');
    await handleRollover({
      sourcePollaRef: pollaRef,
      sourcePollaId: pollaId,
      reason: 'No hubo ganadores',
    });

    const completeBatch = db.batch();
    for (const update of betUpdates) {
      completeBatch.update(update.ref, { status: 'COMPLETED' });
    }
    await completeBatch.commit();

    await pollaRef.update({
      status: 'FINISHED',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      winnerCount: 0,
      message: 'No hubo ganadores. El acumulado continúa.'
    });
    return;
  }

  console.log(`   🏆 Ganadores: ${winnerCount} (con ${maxHits} aciertos)`);
  for (const winner of winners) {
    console.log(`      - ${winner.betId}`);
  }

  // 7. Calcular premios
  const settingsDoc = await db.doc('settings/global').get();
  const basePot = settingsDoc.data()?.basePot ?? 100000;
  const pot = pollaData?.prizeAmount ?? basePot;

  const rawPrize = Math.floor(pot / winnerCount);
  const winnerPrize = rawPrize - (rawPrize % COP_MIN_UNIT);
  const totalPaid = winnerPrize * winnerCount;
  const remainder = pot - totalPaid;

  console.log(`   💰 Pozo jornada: ${pot.toLocaleString()}`);
  console.log(`   💰 Premio por ganador: ${winnerPrize.toLocaleString()}`);
  console.log(`   💰 Restante (carry): ${remainder.toLocaleString()}`);

  // 8. Actualizar apuestas ganadoras
  const winnerBatch = db.batch();
  for (const winner of winners) {
    winnerBatch.update(winner.ref, {
      status: 'WINNER',
      prize: winnerPrize
    });
  }

  for (const update of betUpdates) {
    if (update.exactHits !== maxHits && update.exactHits >= MIN_EXACT_HITS_TO_WIN) {
      winnerBatch.update(update.ref, {
        status: 'COMPLETED',
        note: 'Tuvo aciertos pero no fue el máximo'
      });
    } else if (update.exactHits !== maxHits) {
      winnerBatch.update(update.ref, { status: 'COMPLETED' });
    }
  }
  await winnerBatch.commit();

  // 9. Actualizar polla
  await pollaRef.update({
    status: 'FINISHED',
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    winnerCount: winnerCount,
    winnerPrize: winnerPrize,
    winnerIds: winners.map(w => w.ref.id),
    maxExactHits: maxHits
  });

  // 10. Vaciar pozo y trasladar remainder
  await db.runTransaction(async (tx) => {
    tx.update(pollaRef, { prizeAmount: 0, finalPrizeAmount: pot });
  });

  if (remainder > 0) {
    await moveCarryToNextOrPending(remainder, {
      sourcePollaId: pollaId,
      note: 'Resto por redondeo a múltiplo de 50',
    });
  }

  console.log(`\n   ✅ Polla ${pollaId} finalizada\n`);
}

async function findOpenPollaForBets() {
  const snap = await db.collection('pollas')
    .where('status', '==', 'ACTIVE')
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.closedAt == null) return doc;
  }
  return null;
}

async function moveCarryToNextOrPending(amount, { sourcePollaId, note }) {
  const settingsRef = db.doc('settings/global');
  const openPollaDoc = await findOpenPollaForBets();

  await db.runTransaction(async (tx) => {
    const settingsSnap = await tx.get(settingsRef);
    const settings = settingsSnap.exists ? (settingsSnap.data() || {}) : {};
    const pendingCarry = typeof settings.pendingCarry === 'number' ? settings.pendingCarry : 0;
    const basePot = typeof settings.basePot === 'number' ? settings.basePot : 100000;

    if (!settingsSnap.exists) {
      tx.set(settingsRef, {
        betPrice: 5000,
        accumulatedPercentage: 60,
        basePot,
        pendingCarry: pendingCarry,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (openPollaDoc) {
      const destRef = db.collection('pollas').doc(openPollaDoc.id);
      const destSnap = await tx.get(destRef);
      const dest = destSnap.data() || {};
      const destPrev = typeof dest.prizeAmount === 'number' ? dest.prizeAmount : basePot;
      const destNew = destPrev + amount;
      tx.update(destRef, { prizeAmount: destNew, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

      tx.set(db.collection('accumulated_history').doc(), {
        betId: null,
        pollaId: openPollaDoc.id,
        increment: 0,
        pendingAccumulated: amount,
        previousAccumulated: destPrev,
        newAccumulated: destNew,
        note: note || 'carry',
        sourcePollaId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      const newPending = pendingCarry + amount;
      tx.update(settingsRef, { pendingCarry: newPending, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.set(db.collection('accumulated_history').doc(), {
        betId: null,
        pollaId: null,
        increment: 0,
        pendingAccumulated: amount,
        previousAccumulated: pendingCarry,
        newAccumulated: newPending,
        note: note || 'carry_pending',
        sourcePollaId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

async function handleRollover({ sourcePollaRef, sourcePollaId, reason }) {
  const sourceSnap = await sourcePollaRef.get();
  const pot = sourceSnap.data()?.prizeAmount ?? 0;
  if (!pot || pot <= 0) return;

  await db.runTransaction(async (tx) => {
    tx.update(sourcePollaRef, { prizeAmount: 0, finalPrizeAmount: pot });
  });

  await moveCarryToNextOrPending(pot, {
    sourcePollaId,
    note: reason || 'rollover',
  });
}

// ─── Ejecutar ───────────────────────────────────────────────────────
main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
