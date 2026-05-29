// ingresaResultado_common.js
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Leer el archivo de credenciales
const serviceAccount = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'serviceAccountKey.json'), 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const resultados = {
  'match_1': { home: 1, away: 2 },
  'match_2': { home: 0, away: 0 },
  'match_3': { home: 0, away: 0 },
  'match_4': { home: 0, away: 1 },
  //'match_5': { home: 2, away: 0 },
  //'match_6': { home: 1, away: 2 },
  //'match_7': { home: 2, away: 2 },
  //'match_8': { home: 3, away: 0 },
};

async function ingresarResultados() {
  console.log('🔄 Actualizando resultados...');

  for (const [docId, result] of Object.entries(resultados)) {
    await db.collection('matches').doc(docId).update({
      realHomeScore: result.home,
      realAwayScore: result.away,
      status: 'FINISHED',
    });
    console.log(`✅ ${docId}: ${result.home} - ${result.away}`);
  }

  console.log('✅ Listo!');
}

ingresarResultados();