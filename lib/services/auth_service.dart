import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = result.user;
    if (user == null) return null;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    final newUser = UserModel(
      uid: user.uid,
      phone: phone,
      name: name,
      role: role,
      createdAt: DateTime.now(),
      fcmToken: fcmToken,
    );

    final batch = _db.batch();
    batch.set(
        _db.collection(AppConstants.usersCol).doc(user.uid), newUser.toMap());

    final walletCol = role == 'driver'
        ? AppConstants.driverWalletsCol
        : AppConstants.passengerWalletsCol;
    batch.set(_db.collection(walletCol).doc(user.uid), {
      'uid': user.uid,
      'balance': 0.0,
      'totalTopUp': 0.0,
      'totalEarned': 0.0,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return newUser;
  }

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = result.user;
    if (user == null) return null;
    final doc =
        await _db.collection(AppConstants.usersCol).doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> sendPasswordReset(String email) async =>
      _auth.sendPasswordResetEmail(email: email);

  Future<UserModel?> getCurrentUserModel() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc =
        await _db.collection(AppConstants.usersCol).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> userModelStream() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection(AppConstants.usersCol)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> signOut() async => _auth.signOut();

  Future<void> updateFcmToken(String token) async {
    final uid = currentUid;
    if (uid == null) return;
    await _db.collection(AppConstants.usersCol).doc(uid).update({
      'fcmToken': token,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
