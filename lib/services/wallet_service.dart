import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

  /// Demo/manual top-up. Wallet documents are `allow write: if false` in
  /// firestore.rules, so the balance is mutated by the secure
  /// `walletTopUp` Cloud Function, never directly from the client — this
  /// simulates the M-Pesa flow without moving real money, the same way
  /// the old client-side version did, but safely.
  Future<TopUpResult> simulateTopUp(double amount) async {
    if (amount < 10) return TopUpResult.failure('Minimum top-up is KSh 10');
    try {
      await Future.delayed(const Duration(seconds: 2)); // simulate STK delay
      final callable = _functions.httpsCallable('walletTopUp');
      await callable.call({'amount': amount});
      return TopUpResult.success(amount);
    } on FirebaseFunctionsException catch (e) {
      return TopUpResult.failure(e.message ?? 'Top-up failed.');
    } catch (e) {
      return TopUpResult.failure(e.toString());
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