import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class VehicleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String get _uid => _auth.currentUser!.uid;

  Future<VehicleModel> registerVehicle({
    required String plate,
    required String route,
    List<String> stages = const [],
  }) async {
    final vehicleId = plate.replaceAll(' ', '').toUpperCase();
    final qrPayload = jsonEncode({
      'vehicleId': vehicleId,
      'plate': plate,
      'route': route,
      'ownerUid': _uid,
    });

    final vehicle = VehicleModel(
      vehicleId: vehicleId,
      ownerUid: _uid,
      plate: plate,
      route: route,
      qrPayload: qrPayload,
      stages: stages,
    );

    await _db
        .collection(AppConstants.vehiclesCol)
        .doc(vehicleId)
        .set(vehicle.toMap());
    await _db
        .collection(AppConstants.usersCol)
        .doc(_uid)
        .update({'vehicleId': vehicleId});
    return vehicle;
  }

  Stream<VehicleModel?> driverVehicleStream() => _db
      .collection(AppConstants.vehiclesCol)
      .where('ownerUid', isEqualTo: _uid)
      .limit(1)
      .snapshots()
      .map((s) =>
          s.docs.isEmpty ? null : VehicleModel.fromFirestore(s.docs.first));

  Future<QrValidationResult> validateQrCode(String rawQr) async {
    try {
      final payload = jsonDecode(rawQr) as Map<String, dynamic>;
      final vehicleId = payload['vehicleId'] as String?;
      if (vehicleId == null || vehicleId.isEmpty) {
        return QrValidationResult.failure('Invalid QR code format.');
      }
      final doc = await _db
          .collection(AppConstants.vehiclesCol)
          .doc(vehicleId)
          .get();
      if (!doc.exists) {
        return QrValidationResult.failure('Vehicle not registered.');
      }
      final vehicle = VehicleModel.fromFirestore(doc);
      if (!vehicle.isActive) {
        return QrValidationResult.failure('This vehicle is inactive.');
      }
      return QrValidationResult.success(vehicle);
    } catch (_) {
      return QrValidationResult.failure('Could not read QR code.');
    }
  }
}

class QrValidationResult {
  final bool isSuccess;
  final VehicleModel? vehicle;
  final String? error;
  const QrValidationResult._({required this.isSuccess, this.vehicle, this.error});
  factory QrValidationResult.success(VehicleModel v) =>
      QrValidationResult._(isSuccess: true, vehicle: v);
  factory QrValidationResult.failure(String e) =>
      QrValidationResult._(isSuccess: false, error: e);
}
