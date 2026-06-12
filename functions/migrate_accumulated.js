const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '..', 'scripts', 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateOldAccumulated() {
  console.log('📊 Migrando accumulated antiguo...\n');

  const settingsRef = db.doc('settings/global');
  const settingsSnap = await settingsRef.get();
  if (!settingsSnap.exists) {
    console.log('❌ settings/global no existe');
    return;
  }

  const settings = settingsSnap.data();
  const oldAccumulated = settings.currentAccumulated ?? 0;
  console.log(`   Old currentAccumulated: ${oldAccumulated}`);

  if (oldAccumulated === 0) {
    console.log('   ✅ No hay accumulated antiguo que migrar');
    return;
  }

  const pollasSnap = await db.collection('pollas')
    .where('status', '==', 'ACTIVE')
    .get();

  let openPolla = null;
  for (const doc of pollasSnap.docs) {
    if (doc.data().closedAt == null) {
      openPolla = doc;
      break;
    }
  }

  if (!openPolla) {
    console.log('   No hay polla abierta → migrando a pendingCarry');
    await settingsRef.update({
      pendingCarry: admin.firestore.FieldValue.increment(oldAccumulated),
      currentAccumulated: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`   ✅ ${oldAccumulated} movido a settings/global.pendingCarry`);
    return;
  }

  const pollaRef = db.collection('pollas').doc(openPolla.id);
  const pollaSnap = await openPolla.ref.get();
  const polla = pollaSnap.data() || {};
  const currentPrize = typeof polla.prizeAmount === 'number' ? polla.prizeAmount : 0;

  console.log(`   Polla activa: ${openPolla.id} (${polla.name})`);
  console.log(`   PrizeAmount actual: ${currentPrize}`);

  await db.runTransaction(async (tx) => {
    const newPrize = currentPrize + oldAccumulated;
    tx.update(pollaRef, {
      prizeAmount: newPrize,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(settingsRef, {
      currentAccumulated: 0,
      pendingCarry: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('accumulated_history').doc(), {
      betId: null,
      pollaId: openPolla.id,
      increment: 0,
      pendingAccumulated: oldAccumulated,
      previousAccumulated: currentPrize,
      newAccumulated: newPrize,
      note: 'migracion_old_accumulated',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log(`   ✅ ${oldAccumulated} migrado a ${openPolla.id}.prizeAmount`);
  console.log(`   Nuevo prizeAmount: ${currentPrize + oldAccumulated}`);
}

migrateOldAccumulated()
  .then(() => {
    console.log('\n✅ Migración completada');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
