// scripts/update_results.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Resultados reales de la jornada
const resultados = {
  'match_1': { home: 2, away: 1 },
  'match_2': { home: 1, away: 1 },
  'match_3': { home: 0, away: 0 },
  'match_4': { home: 3, away: 2 },
  'match_5': { home: 2, away: 0 },
  'match_6': { home: 1, away: 2 },
  'match_7': { home: 2, away: 2 },
  'match_8': { home: 3, away: 1 },
};

async function updateResults() {
  console.log('🔄 Actualizando resultados de partidos...\n');

  for (const [matchId, result] of Object.entries(resultados)) {
    await db.collection('matches').doc(matchId).update({
      realHomeScore: result.home,
      realAwayScore: result.away,
      status: 'FINISHED'
    });
    console.log(`✅ ${matchId}: ${result.home} - ${result.away}`);
  }

  console.log('\n🎯 Todos los resultados actualizados');
  console.log('👉 Ahora ejecuta: node run_scrutiny.js');
}

updateResults()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });