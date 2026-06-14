import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Stream<WalletModel> passengerWalletStream(String uid) => _db
      .collection(AppConstants.passengerWalletsCol)
      .doc(uid)
      .snapshots()
      .map((doc) => WalletModel.fromFirestore(doc));

  Stream<WalletModel> driverWalletStream(String uid) => _db
      .collection(AppConstants.driverWalletsCol)
      .doc(uid)
      .snapshots()
      .map((doc) => WalletModel.fromFirestore(doc));

  Stream<List<TransactionModel>> transactionStream(String uid) => _db
      .collection(AppConstants.transactionsCol)
      .where('uid', isEqualTo: uid)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());

  /// MVP: Simulates M-Pesa top-up without calling real API.
  Future<TopUpResult> simulateTopUp(double amount) async {
    if (amount < 10) return TopUpResult.failure('Minimum top-up is KSh 10');
    try {
      final walletRef =
          _db.collection(AppConstants.passengerWalletsCol).doc(_uid);
      final txnRef = _db.collection(AppConstants.transactionsCol).doc();

      await Future.delayed(const Duration(seconds: 2)); // simulate STK delay

      await _db.runTransaction((txn) async {
        final wallet = await txn.get(walletRef);
        final current = (wallet.data()?['balance'] ?? 0).toDouble();
        final newBal = current + amount;

        txn.update(walletRef, {
          'balance': newBal,
          'totalTopUp': FieldValue.increment(amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        txn.set(txnRef, {
          'uid': _uid,
          'type': 'topup',
          'amount': amount,
          'balanceBefore': current,
          'balanceAfter': newBal,
          'mpesaRef': 'SIM${DateTime.now().millisecondsSinceEpoch}',
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Wallet top-up (M-Pesa simulated)',
          'tripId': null,
        });
      });

      return TopUpResult.success(amount);
    } catch (e) {
      return TopUpResult.failure(e.toString());
    }
  }

  Future<FareResult> deductFare({
    required String tripId,
    required String passengerId,
    required String driverUid,
    required double distanceKm,
  }) async {
    final distanceFare = distanceKm * AppConstants.ratePerKm;
    final totalFare = AppConstants.baseFare + distanceFare;
    final driverEarning = totalFare * (1 - AppConstants.platformFeePercent);

    final pWalletRef =
        _db.collection(AppConstants.passengerWalletsCol).doc(passengerId);
    final dWalletRef =
        _db.collection(AppConstants.driverWalletsCol).doc(driverUid);

    try {
      await _db.runTransaction((txn) async {
        final pWallet = await txn.get(pWalletRef);
        final dWallet = await txn.get(dWalletRef);
        final pBalance = (pWallet.data()?['balance'] ?? 0).toDouble();
        final dBalance = (dWallet.data()?['balance'] ?? 0).toDouble();

        if (pBalance < totalFare) {
          throw Exception(
              'Insufficient balance. Need KSh ${totalFare.toStringAsFixed(0)}, have KSh ${pBalance.toStringAsFixed(0)}');
        }

        txn.update(pWalletRef, {
          'balance': pBalance - totalFare,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        txn.update(dWalletRef, {
          'balance': dBalance + driverEarning,
          'totalEarned': FieldValue.increment(driverEarning),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        txn.set(_db.collection(AppConstants.transactionsCol).doc(), {
          'uid': passengerId,
          'type': 'fare_debit',
          'amount': totalFare,
          'balanceBefore': pBalance,
          'balanceAfter': pBalance - totalFare,
          'tripId': tripId,
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Trip fare - ${distanceKm.toStringAsFixed(1)} km',
        });

        txn.set(_db.collection(AppConstants.transactionsCol).doc(), {
          'uid': driverUid,
          'type': 'fare_credit',
          'amount': driverEarning,
          'balanceBefore': dBalance,
          'balanceAfter': dBalance + driverEarning,
          'tripId': tripId,
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Trip earnings - ${distanceKm.toStringAsFixed(1)} km',
        });
      });

      return FareResult.success(
          totalFare: totalFare,
          distanceFare: distanceFare,
          baseFare: AppConstants.baseFare);
    } catch (e) {
      return FareResult.failure(e.toString());
    }
  }

  Future<bool> hasSufficientBalance(String uid, double min) async {
    final doc = await _db
        .collection(AppConstants.passengerWalletsCol)
        .doc(uid)
        .get();
    return (doc.data()?['balance'] ?? 0).toDouble() >= min;
  }
}

class TopUpResult {
  final bool isSuccess;
  final double? amount;
  final String? error;
  const TopUpResult._({required this.isSuccess, this.amount, this.error});
  factory TopUpResult.success(double a) =>
      TopUpResult._(isSuccess: true, amount: a);
  factory TopUpResult.failure(String e) =>
      TopUpResult._(isSuccess: false, error: e);
}

class FareResult {
  final bool isSuccess;
  final double? totalFare;
  final double? distanceFare;
  final double? baseFare;
  final String? error;
  const FareResult._(
      {required this.isSuccess,
      this.totalFare,
      this.distanceFare,
      this.baseFare,
      this.error});
  factory FareResult.success(
          {required double totalFare,
          required double distanceFare,
          required double baseFare}) =>
      FareResult._(
          isSuccess: true,
          totalFare: totalFare,
          distanceFare: distanceFare,
          baseFare: baseFare);
  factory FareResult.failure(String e) =>
      FareResult._(isSuccess: false, error: e);
}
