const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();

// ─── Haversine ────────────────────────────────────────────────────
function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─── Get M-Pesa token ─────────────────────────────────────────────
async function getMpesaToken() {
  const creds = Buffer.from(
    `${process.env.MPESA_CONSUMER_KEY}:${process.env.MPESA_CONSUMER_SECRET}`
  ).toString('base64');
  const res = await axios.get(
    'https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials',
    { headers: { Authorization: `Basic ${creds}` } }
  );
  return res.data.access_token;
}

// ─── STK Push (real M-Pesa) ───────────────────────────────────────
exports.initiateStkPush = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  const { amount, phone } = data;
  const uid = context.auth.uid;
  if (!amount || amount < 10) throw new functions.https.HttpsError('invalid-argument', 'Min KSh 10.');

  const normalizedPhone = `254${phone.replace(/^0|^\+254/, '')}`;

  try {
    const token = await getMpesaToken();
    const shortcode = process.env.MPESA_SHORTCODE;
    const passkey = process.env.MPESA_PASSKEY;
    const ts = new Date().toISOString().replace(/[-T:.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${shortcode}${passkey}${ts}`).toString('base64');

    const stkRes = await axios.post(
      'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
      {
        BusinessShortCode: shortcode, Password: password, Timestamp: ts,
        TransactionType: 'CustomerPayBillOnline', Amount: Math.ceil(amount),
        PartyA: normalizedPhone, PartyB: shortcode, PhoneNumber: normalizedPhone,
        CallBackURL: `${process.env.BASE_URL}/mpesaCallback`,
        AccountReference: `TransitPay-${uid.slice(0, 8)}`,
        TransactionDesc: 'Transit Pay Wallet Top-up',
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    await db.collection('transactions').add({
      uid, type: 'topup', amount, status: 'pending',
      checkoutRequestId: stkRes.data.CheckoutRequestID,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Wallet top-up via M-Pesa',
    });

    return { success: true, checkoutRequestId: stkRes.data.CheckoutRequestID };
  } catch (err) {
    console.error('STK error:', err.response?.data || err.message);
    throw new functions.https.HttpsError('internal', 'Payment initiation failed.');
  }
});

// ─── M-Pesa Callback ──────────────────────────────────────────────
exports.mpesaCallback = functions.https.onRequest(async (req, res) => {
  try {
    const cb = req.body?.Body?.stkCallback;
    if (!cb) return res.status(200).send('OK');

    const checkoutId = cb.CheckoutRequestID;
    const resultCode = cb.ResultCode;

    const snap = await db.collection('transactions')
      .where('checkoutRequestId', '==', checkoutId)
      .where('status', '==', 'pending').limit(1).get();

    if (snap.empty) return res.status(200).send('OK');

    const txnDoc = snap.docs[0];
    const { uid, amount } = txnDoc.data();

    if (resultCode === 0) {
      const items = cb.CallbackMetadata?.Item || [];
      const mpesaRef = items.find(i => i.Name === 'MpesaReceiptNumber')?.Value || 'N/A';

      await db.runTransaction(async txn => {
        const walletRef = db.collection('passengerWallets').doc(uid);
        const wallet = await txn.get(walletRef);
        const current = wallet.data()?.balance ?? 0;
        const newBal = current + amount;

        txn.update(walletRef, {
          balance: newBal,
          totalTopUp: admin.firestore.FieldValue.increment(amount),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
        txn.update(txnDoc.ref, {
          status: 'success', mpesaRef, balanceBefore: current, balanceAfter: newBal,
        });
      });
    } else {
      await txnDoc.ref.update({ status: 'failed', resultCode });
    }
    res.status(200).send('OK');
  } catch (err) {
    console.error('Callback error:', err);
    res.status(200).send('OK');
  }
});

// ─── End Trip & Deduct Fare ───────────────────────────────────────
exports.endTrip = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  const { tripId, endLat, endLng } = data;
  const uid = context.auth.uid;

  const tripRef = db.collection('trips').doc(tripId);
  const tripDoc = await tripRef.get();
  if (!tripDoc.exists) throw new functions.https.HttpsError('not-found', 'Trip not found.');

  const trip = tripDoc.data();
  if (trip.passengerId !== uid) throw new functions.https.HttpsError('permission-denied');
  if (trip.status !== 'active') throw new functions.https.HttpsError('failed-precondition', 'Trip not active.');

  const history = [...(trip.locationHistory || [])];
  const endPoint = new admin.firestore.GeoPoint(endLat, endLng);
  history.push(endPoint);

  let dist = 0;
  for (let i = 1; i < history.length; i++) {
    dist += haversine(
      history[i-1].latitude, history[i-1].longitude,
      history[i].latitude,   history[i].longitude
    );
  }
  dist = Math.round(dist * 100) / 100;

  const BASE = 20, RATE = 3, FEE = 0.05;
  const distFare = Math.round(dist * RATE * 100) / 100;
  const totalFare = Math.round((BASE + distFare) * 100) / 100;
  const driverEarn = Math.round(totalFare * (1 - FEE) * 100) / 100;

  const pWalletRef = db.collection('passengerWallets').doc(trip.passengerId);
  const dWalletRef = db.collection('driverWallets').doc(trip.driverUid);

  await tripRef.update({ status: 'processing' });

  try {
    await db.runTransaction(async txn => {
      const [pWallet, dWallet] = await Promise.all([txn.get(pWalletRef), txn.get(dWalletRef)]);
      const pBal = pWallet.data()?.balance ?? 0;
      const dBal = dWallet.data()?.balance ?? 0;

      if (pBal < totalFare) throw new Error(`Insufficient balance. Need KSh ${totalFare.toFixed(0)}, have KSh ${pBal.toFixed(0)}.`);

      txn.update(pWalletRef, { balance: pBal - totalFare, lastUpdated: admin.firestore.FieldValue.serverTimestamp() });
      txn.update(dWalletRef, {
        balance: dBal + driverEarn,
        totalEarned: admin.firestore.FieldValue.increment(driverEarn),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
      txn.set(db.collection('transactions').doc(), {
        uid: trip.passengerId, type: 'fare_debit', amount: totalFare,
        balanceBefore: pBal, balanceAfter: pBal - totalFare, tripId,
        status: 'success', timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: `Trip fare - ${dist.toFixed(1)} km`,
      });
      txn.set(db.collection('transactions').doc(), {
        uid: trip.driverUid, type: 'fare_credit', amount: driverEarn,
        balanceBefore: dBal, balanceAfter: dBal + driverEarn, tripId,
        status: 'success', timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: `Trip earnings - ${dist.toFixed(1)} km`,
      });
      txn.update(tripRef, {
        status: 'completed', endLocation: endPoint,
        endTime: admin.firestore.FieldValue.serverTimestamp(),
        distanceKm: dist, distanceFare: distFare, totalFare, locationHistory: history,
      });
    });
    return { success: true, totalFare, distanceKm: dist, distanceFare: distFare, baseFare: BASE };
  } catch (err) {
    await tripRef.update({ status: 'active' }).catch(() => {});
    throw new functions.https.HttpsError('internal', err.message);
  }
});

// ─── Trip status push notifications ──────────────────────────────
exports.sendTripNotification = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status) return null;

    let title, body;
    if (after.status === 'active') {
      title = '🚍 Trip Started'; body = `You boarded ${after.vehicleId}. Safe travels!`;
    } else if (after.status === 'completed') {
      title = '✅ Trip Completed';
      body = `KSh ${after.totalFare?.toFixed(0) ?? '0'} deducted for ${after.distanceKm?.toFixed(1) ?? '0'} km.`;
    } else { return null; }

    const userDoc = await db.collection('users').doc(after.passengerId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;

    return admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: { notification: { channelId: 'transit_pay' } },
    });
  });

// ─── Low balance alert ────────────────────────────────────────────
exports.lowBalanceAlert = functions.firestore
  .document('passengerWallets/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (after.balance < 50 && before.balance >= 50) {
      const userDoc = await db.collection('users').doc(context.params.uid).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) return null;
      return admin.messaging().send({
        token: fcmToken,
        notification: {
          title: '⚠️ Low Balance',
          body: `Your wallet has KSh ${after.balance.toFixed(0)}. Top up to keep riding.`,
        },
      });
    }
    return null;
  });
