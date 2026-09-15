/**
 * Transit Pay — demo/seed data
 * ─────────────────────────────────────────────────────────────────
 * Populates Firestore with a handful of clearly-fictional demo
 * vehicles (with routes + stages) so the app can be demoed immediately,
 * without registering a vehicle by hand first. Uses the Admin SDK, so
 * it bypasses firestore.rules — run it from your own machine with a
 * service account key, never ship it inside the app.
 *
 * Setup (one-time):
 *   cd scripts
 *   npm install firebase-admin
 *
 * Usage:
 *   node seed_demo_data.js <path-to-service-account.json> [driverUid] [passengerUid]
 *
 *   <path-to-service-account.json>  Required. Download from Firebase
 *     Console → Project Settings → Service Accounts → Generate new
 *     private key.
 *
 *   [driverUid]     Optional. A real driver's uid (from the `users`
 *     collection) to own the demo vehicles. If omitted, a placeholder
 *     "DEMO_DRIVER" is used — trip settlement will still work, the
 *     driver just won't see these vehicles under "My Vehicle" unless
 *     you pass their real uid.
 *
 *   [passengerUid]  Optional. If given, tops up that passenger's
 *     wallet to KSh 1,000 (via a direct write — this script runs with
 *     admin privileges, so it can do this safely outside the app;
 *     the app itself never writes wallets directly, see walletTopUp
 *     in functions/src/index.js).
 *
 * After seeding, open the driver app, register nothing further — the
 * vehicles already exist. To demo scanning, either:
 *   a) Log in as the driver whose uid you passed, open the QR tab —
 *      their vehicle's real QR renders there, or
 *   b) Paste one of the printed JSON payloads below into any QR
 *      generator (e.g. a "text to QR" site) and scan the printout.
 */

const admin = require('firebase-admin');

const [, , keyPath, driverUidArg, passengerUidArg] = process.argv;

if (!keyPath) {
  console.error('Usage: node seed_demo_data.js <path-to-service-account.json> [driverUid] [passengerUid]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(require('path').resolve(keyPath))) });
const db = admin.firestore();

const driverUid = driverUidArg || 'DEMO_DRIVER';

const demoVehicles = [
  {
    plate: 'KCA 123A',
    route: 'CBD - Rongai',
    stages: ['CBD', 'Kenyatta', 'Nyayo', 'Bunyala', 'Rongai'],
  },
  {
    plate: 'KDB 456B',
    route: 'CBD - Ngong',
    stages: ['CBD', 'Adams Arcade', 'Prestige', 'Junction', 'Ngong'],
  },
  {
    plate: 'KDC 789C',
    route: 'CBD - Kikuyu',
    stages: ['CBD', 'Westlands', 'Kawangware', 'Dagoretti', 'Kikuyu'],
  },
];

async function seed() {
  console.log(`Seeding demo vehicles for driverUid="${driverUid}"...\n`);

  for (const v of demoVehicles) {
    const vehicleId = v.plate.replace(/\s+/g, '').toUpperCase();
    const qrPayload = JSON.stringify({
      vehicleId,
      plate: v.plate,
      route: v.route,
      ownerUid: driverUid,
    });

    await db.collection('vehicles').doc(vehicleId).set({
      vehicleId,
      ownerUid: driverUid,
      plate: v.plate,
      route: v.route,
      stages: v.stages,
      qrPayload,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`✓ ${v.plate}  (${v.route})`);
    console.log(`  QR payload: ${qrPayload}\n`);
  }

  if (passengerUidArg) {
    const walletRef = db.collection('passengerWallets').doc(passengerUidArg);
    await walletRef.set({
      uid: passengerUidArg,
      balance: 1000,
      totalTopUp: admin.firestore.FieldValue.increment(1000),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`✓ Topped up passenger ${passengerUidArg} to KSh 1,000 for the demo.\n`);
  } else {
    console.log('No passengerUid given — skip wallet top-up. Use the app\'s normal Top Up flow instead.\n');
  }

  console.log('Done. Demo vehicles are ready to scan.');
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
