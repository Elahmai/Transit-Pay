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

// ─── Secure demo/manual wallet top-up ──────────────────────────────
// Passenger wallets have `allow write: if false` in firestore.rules, so
// every balance change must go through a Cloud Function. This is the
// secure counterpart of the old client-side "simulateTopUp" — same
// no-real-money-moves demo behaviour, but the balance mutation now
// happens server-side where it can be validated.
exports.walletTopUp = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  const uid = context.auth.uid;
  const amount = Number(data.amount);

  if (!amount || !Number.isFinite(amount) || amount < 10) {
    throw new functions.https.HttpsError('invalid-argument', 'Minimum top-up is KSh 10.');
  }
  if (amount > 150000) {
    throw new functions.https.HttpsError('invalid-argument', 'Maximum top-up is KSh 150,000.');
  }

  const walletRef = db.collection('passengerWallets').doc(uid);
  const txnRef = db.collection('transactions').doc();

  try {
    const newBalance = await db.runTransaction(async (txn) => {
      const wallet = await txn.get(walletRef);
      const current = wallet.exists ? (wallet.data().balance ?? 0) : 0;
      const newBal = Math.round((current + amount) * 100) / 100;

      txn.set(walletRef, {
        uid,
        balance: newBal,
        totalTopUp: admin.firestore.FieldValue.increment(amount),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      txn.set(txnRef, {
        uid, type: 'topup', amount,
        balanceBefore: current, balanceAfter: newBal,
        mpesaRef: `SIM${Date.now()}`,
        status: 'success',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Wallet top-up (simulated for demo)',
        tripId: null,
      });

      return newBal;
    });

    return { success: true, amount, balance: newBalance };
  } catch (err) {
    console.error('walletTopUp error:', err);
    throw new functions.https.HttpsError('internal', 'Top-up failed. Please try again.');
  }
});

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

  // Same formula the app shows as the live estimate (base + per-km, with a
  // 50% child discount), so the amount actually charged here always
  // matches what the passenger was told to expect — never more, never less.
  const BASE = 20, RATE = 3, FEE = 0.05, CHILD_DISCOUNT = 0.5;
  const adults = trip.adults || 1;
  const children = trip.children || 0;
  const perKmFare = dist * RATE;
  const distFare = Math.round(perKmFare * 100) / 100;
  const adultFare = adults * (BASE + perKmFare);
  const childFare = children * (BASE + perKmFare) * CHILD_DISCOUNT;
  const totalFare = Math.round((adultFare + childFare) * 100) / 100;
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

// ─── Transit AI assistant ───────────────────────────────────────────
// Intent-based Q&A over the passenger's *real* Transit Pay data. This is
// deliberately NOT a free-form LLM call: every number it says comes
// straight from Firestore, so it can never invent a fare or balance.
// `AiService`/`FirebaseAiService` on the Flutter side are written as a
// thin swappable client, so a real LLM (kept behind this same secure
// callable, never with a key in the app) can be dropped in later without
// touching the UI — see lib/services/ai_service.dart.
// The assistant never writes anything; it is read-only by construction.

function fmtKsh(n) {
  return `KSh ${Number(n).toFixed(0)}`;
}

async function aiGetWallet(uid) {
  const doc = await db.collection('passengerWallets').doc(uid).get();
  return doc.exists ? (doc.data().balance ?? 0) : 0;
}

async function aiGetActiveTrip(uid) {
  const snap = await db.collection('trips')
    .where('passengerId', '==', uid)
    .where('status', '==', 'active')
    .limit(1).get();
  return snap.empty ? null : { id: snap.docs[0].id, ...snap.docs[0].data() };
}

async function aiGetRecentTrips(uid, n) {
  const snap = await db.collection('trips')
    .where('passengerId', '==', uid)
    .orderBy('startTime', 'desc')
    .limit(n).get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

async function aiGetSpending(uid, days) {
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - days * 86400000);
  const snap = await db.collection('transactions')
    .where('uid', '==', uid)
    .where('type', '==', 'fare_debit')
    .where('timestamp', '>=', since)
    .get();
  let total = 0;
  snap.forEach(d => { total += d.data().amount || 0; });
  return { total, count: snap.size };
}

async function aiFindVehicleByRouteHint(text) {
  const snap = await db.collection('vehicles').where('isActive', '==', true).get();
  const hint = text.toLowerCase();
  for (const doc of snap.docs) {
    const v = doc.data();
    if ((v.route || '').toLowerCase().includes(hint) ||
        (v.stages || []).some(s => hint.includes(s.toLowerCase()))) {
      return v;
    }
  }
  return null;
}

function estimateForTrip(trip) {
  const BASE = 20, RATE = 3, CHILD_DISCOUNT = 0.5;
  const dist = trip.distanceKm || 0;
  const adults = trip.adults || 1;
  const children = trip.children || 0;
  const perKm = dist * RATE;
  return Math.round((adults * (BASE + perKm) + children * (BASE + perKm) * CHILD_DISCOUNT) * 100) / 100;
}

exports.assistantQuery = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  const uid = context.auth.uid;
  const message = String(data.message || '').trim();
  if (!message) throw new functions.https.HttpsError('invalid-argument', 'Message is required.');
  const m = message.toLowerCase();

  try {
    // Checked roughly most-specific-first so overlapping keywords (e.g. a
    // spending question that happens to mention "fare") land in the
    // intent that actually answers them.

    // 1. Spending insights ("this week", "how much did I spend")
    if (/\b(spend|spent|spending)\b/.test(m)) {
      const days = /\bmonth\b/.test(m) ? 30 : 7;
      const { total, count } = await aiGetSpending(uid, days);
      if (count === 0) {
        return { reply: `I don't see any completed trips in the last ${days} days, so there's no spending to report yet.` };
      }
      const avg = total / count;
      return {
        reply: `You spent approximately ${fmtKsh(total)} on Transit Pay trips over the last ${days} days.\n\nTrips: ${count}\nAverage fare: ${fmtKsh(avg)}`,
      };
    }

    // 2. Wallet balance
    if (/\b(wallet|balance|how much money|money (do i have|in my))\b/.test(m)) {
      const balance = await aiGetWallet(uid);
      return { reply: `Your Transit Pay wallet balance is ${fmtKsh(balance)}.` };
    }

    // 3. Recent / last trip, "which route did I take"
    if (/\b(last trip|recent trip|which route|yesterday|my trips?)\b/.test(m)) {
      const trips = await aiGetRecentTrips(uid, /\b(recent trips)\b/.test(m) ? 5 : 1);
      if (trips.length === 0) {
        return { reply: "You don't have any trips on record yet. Scan a matatu's QR code to take your first one." };
      }
      if (trips.length === 1) {
        const t = trips[0];
        const when = t.startTime && t.startTime.toDate ? t.startTime.toDate().toDateString() : 'a recent date';
        const status = t.status === 'completed'
          ? `completed, ${fmtKsh(t.totalFare || 0)} charged for ${(t.distanceKm || 0).toFixed(1)} km`
          : t.status;
        return { reply: `Your last recorded trip was on ${t.vehicleId} on ${when} — ${status}.` };
      }
      const lines = trips.map(t => {
        const when = t.startTime && t.startTime.toDate ? t.startTime.toDate().toDateString() : '';
        return `• ${t.vehicleId} · ${when} · ${t.status === 'completed' ? fmtKsh(t.totalFare || 0) : t.status}`;
      });
      return { reply: `Here are your ${trips.length} most recent trips:\n\n${lines.join('\n')}` };
    }

    // 4. Route / stage lookup (checked before the generic fare intent so
    // "what stages are on the Rongai route" doesn't get swallowed by it)
    if (/\b(stage|stages|stops|which route)\b/.test(m)) {
      const vehicle = await aiFindVehicleByRouteHint(message);
      if (!vehicle) {
        return { reply: "I couldn't find a registered route matching that in Transit Pay yet. Try naming one of the stops, e.g. \"What stages are on the Rongai route?\"" };
      }
      const stages = (vehicle.stages && vehicle.stages.length) ? vehicle.stages.join(', ') : null;
      return {
        reply: stages
          ? `The ${vehicle.route} route (vehicle ${vehicle.plate}) currently shows these stages in Transit Pay: ${stages}.`
          : `I found the ${vehicle.route} route (vehicle ${vehicle.plate}), but no detailed stage list has been added for it yet.`,
      };
    }

    // 5. Active-trip fare / affordability questions — deliberately broad
    // ("fare", "afford", "enough") since this is the assistant's most
    // common job, and it safely degrades to "no active trip" when there
    // isn't one to estimate.
    if (/\b(fare|afford|enough|can i pay)\b/.test(m)) {
      const trip = await aiGetActiveTrip(uid);
      if (!trip) {
        return { reply: "You don't have an active trip right now, so there's no live fare estimate to show. Scan a matatu's QR code to start one." };
      }
      const balance = await aiGetWallet(uid);
      const estimate = estimateForTrip(trip);
      const canAfford = balance >= estimate;
      return {
        reply: `Your current trip estimate is ${fmtKsh(estimate)} for ${(trip.distanceKm || 0).toFixed(1)} km so far (this updates as you travel — the final amount is set when you end the trip). Your wallet balance is ${fmtKsh(balance)}, so ${canAfford ? `you're covered, with about ${fmtKsh(balance - estimate)} left over.` : `you're short by about ${fmtKsh(estimate - balance)} — you may want to top up before ending the trip.`}`,
      };
    }

    // Fallback — don't guess, tell the user what's actually answerable.
    return {
      reply: "I can help with things like your wallet balance, your current trip's fare estimate, recent trips, weekly spending, or a route's stages. Try asking one of those, or use the quick options below.",
    };
  } catch (err) {
    console.error('assistantQuery error:', err);
    throw new functions.https.HttpsError('internal', 'Assistant is unavailable right now. Please try again.');
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
