// scripts/run_scrutiny.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const MIN_EXACT_HITS_TO_WIN = 4;

async function runScrutiny() {
  console.log('📊 Iniciando escrutinio manual...\n');

  // Buscar pollas cerradas no procesadas
  const pollasSnapshot = await db.collection('pollas')
    .where('status', 'in', ['CLOSED', 'FINISHED'])
    .where('processedAt', '==', null)
    .get();

  if (pollasSnapshot.empty) {
    console.log('📭 No hay pollas pendientes de escrutinio');
    return;
  }

  console.log(`📊 Encontradas ${pollasSnapshot.size} pollas para procesar\n`);

  for (const pollaDoc of pollasSnapshot.docs) {
    await processPolla(pollaDoc.id);
  }

  console.log('\n✅ Escrutinio completado');
}

async function processPolla(pollaId) {
  console.log(`📊 Procesando polla: ${pollaId}`);

  // 1. Obtener resultados reales
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

  console.log(`   📋 Resultados encontrados: ${Object.keys(results).length} partidos`);

  // 2. Obtener apuestas activas
  const betsSnapshot = await db.collection('bets')
    .where('pollaId', '==', pollaId)
    .where('status', '==', 'ACTIVE')
    .where('deleted', '==', false)
    .get();

  if (betsSnapshot.empty) {
    console.log('   📭 No hay apuestas activas');
    await pollaDoc.ref.update({
      status: 'FINISHED',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      winnerCount: 0
    });
    return;
  }

  console.log(`   📊 Apuestas activas: ${betsSnapshot.size}`);

  // 3. Calcular aciertos de cada apuesta
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

  // 4. Guardar aciertos en Firestore
  const batch = db.batch();
  for (const update of betUpdates) {
    batch.update(update.ref, { exactHits: update.exactHits });
  }
  await batch.commit();

  // 5. ✅ ENCONTRAR EL MÁXIMO DE ACIERTOS (solo entre los que tienen >=4)
  let maxHits = 0;
  for (const update of betUpdates) {
    if (update.exactHits >= MIN_EXACT_HITS_TO_WIN && update.exactHits > maxHits) {
      maxHits = update.exactHits;
    }
  }

  console.log(`\n   🏆 Máximo de aciertos: ${maxHits}`);

  // 6. ✅ SOLO GANAN LOS QUE TIENEN EL MÁXIMO
  const winners = betUpdates.filter(u => u.exactHits === maxHits);
  const winnerCount = winners.length;

  if (maxHits === 0 || winners.length === 0) {
    console.log('   ❌ No hubo ganadores (nadie alcanzó 4 aciertos o más)');
    await pollaDoc.ref.update({
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
  const currentAccumulated = settingsDoc.data()?.currentAccumulated || 100000;
  const winnerPrize = Math.floor(currentAccumulated / winnerCount);
  const remainingAccumulated = currentAccumulated - winnerPrize;

  console.log(`   💰 Premio total: ${currentAccumulated.toLocaleString()}`);
  console.log(`   💰 Premio por ganador: ${winnerPrize.toLocaleString()}`);
  console.log(`   💰 Acumulado restante: ${remainingAccumulated.toLocaleString()}`);

  // 8. Actualizar apuestas ganadoras
  const winnerBatch = db.batch();
  for (const winner of winners) {
    winnerBatch.update(winner.ref, {
      status: 'WINNER',
      prize: winnerPrize
    });
  }

  // Las que no ganaron pero tienen >=4 se marcan como COMPLETED
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
  await pollaDoc.ref.update({
    status: 'FINISHED',
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    winnerCount: winnerCount,
    winnerPrize: winnerPrize,
    winnerIds: winners.map(w => w.ref.id),
    maxExactHits: maxHits
  });

  // 10. Actualizar acumulado global
  await db.doc('settings/global').update({
    currentAccumulated: remainingAccumulated,
    lastWinnerPrize: winnerPrize,
    lastWinnerCount: winnerCount,
    lastWinnerDate: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log(`\n   ✅ Polla ${pollaId} finalizada\n`);
}

// Ejecutar
runScrutiny()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });