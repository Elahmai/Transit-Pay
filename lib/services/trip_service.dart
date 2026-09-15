import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import 'wallet_service.dart';

class TripService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final WalletService _walletService = WalletService();

  Timer? _locationTimer;

  String get _uid => _auth.currentUser!.uid;

  // ─── Streams ──────────────────────────────────────────────────
  Stream<TripModel?> activeTripStream(String uid) => _db
      .collection(AppConstants.tripsCol)
      .where('passengerId', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((s) =>
          s.docs.isEmpty ? null : TripModel.fromFirestore(s.docs.first));

  Stream<List<TripModel>> passengerTripHistoryStream(String uid) => _db
      .collection(AppConstants.tripsCol)
      .where('passengerId', isEqualTo: uid)
      .orderBy('startTime', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map((d) => TripModel.fromFirestore(d)).toList());

  Stream<List<TripModel>> driverTripHistoryStream(String driverUid) => _db
      .collection(AppConstants.tripsCol)
      .where('driverUid', isEqualTo: driverUid)
      .orderBy('startTime', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => TripModel.fromFirestore(d)).toList());

  // ─── Location ─────────────────────────────────────────────────
  Future<bool> requestLocationPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    return perm != LocationPermission.deniedForever;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestLocationPermission()) return null;
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // ─── Start Trip ───────────────────────────────────────────────
  Future<StartTripResult> startTrip(VehicleModel vehicle,
      {int adults = 1, int children = 0}) async {
    try {
      // Check existing active trip
      final existing = await _db
          .collection(AppConstants.tripsCol)
          .where('passengerId', isEqualTo: _uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return StartTripResult.failure(
            'You already have an active trip. End it first.');
      }

      // Check balance
      if (!await _walletService.hasSufficientBalance(
          _uid, AppConstants.minimumBalance)) {
        return StartTripResult.failure(
            'Insufficient balance. Minimum KSh ${AppConstants.minimumBalance.toStringAsFixed(0)} required.');
      }

      // Get GPS
      final position = await getCurrentPosition();
      if (position == null) {
        return StartTripResult.failure(
            'Could not get your location. Please enable GPS and try again.');
      }

      final tripRef = _db.collection(AppConstants.tripsCol).doc();
      final trip = TripModel(
        tripId: tripRef.id,
        passengerId: _uid,
        vehicleId: vehicle.vehicleId,
        driverUid: vehicle.ownerUid,
        status: TripStatus.active,
        startLocation: GeoPoint(position.latitude, position.longitude),
        startTime: DateTime.now(),
        baseFare: AppConstants.baseFare,
        locationHistory: [GeoPoint(position.latitude, position.longitude)],
        adults: adults,
        children: children,
      );

      await tripRef.set(trip.toMap());
      _startTracking(tripRef.id);
      return StartTripResult.success(trip);
    } catch (e) {
      return StartTripResult.failure(e.toString());
    }
  }

  void _startTracking(String tripId) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: AppConstants.locationUpdateIntervalSecs),
      (_) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          final tripRef = _db.collection(AppConstants.tripsCol).doc(tripId);
          final snap = await tripRef.get();
          if (!snap.exists) { _stopTracking(); return; }

          final trip = TripModel.fromFirestore(snap);
          if (trip.status != TripStatus.active) { _stopTracking(); return; }

          final history = List<GeoPoint>.from(trip.locationHistory);
          history.add(GeoPoint(pos.latitude, pos.longitude));

          double total = 0;
          for (int i = 1; i < history.length; i++) {
            total += haversineDistance(history[i - 1], history[i]);
          }

          await tripRef.update({
            'locationHistory': history,
            'distanceKm': double.parse(total.toStringAsFixed(2)),
          });
        } catch (_) {}
      },
    );
  }

  void _stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // ─── End Trip ─────────────────────────────────────────────────
  /// Settlement (distance calc, fare calc, wallet debit/credit,
  /// transaction records) all happens inside the secure `endTrip` Cloud
  /// Function — passenger wallets are `allow write: if false` in
  /// firestore.rules, so the client can never move money on its own,
  /// only ask the backend to do it after re-validating everything.
  Future<EndTripResult> endTrip({
    required String tripId,
    required String scannedVehicleId,
  }) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) return EndTripResult.failure('Trip not found.');
      if (trip.vehicleId != scannedVehicleId) {
        return EndTripResult.failure(
            'QR code does not match your current trip vehicle.');
      }
      if (trip.status != TripStatus.active) {
        return EndTripResult.failure('This trip is already ended.');
      }

      final pos = await getCurrentPosition();
      final endLat = pos?.latitude ?? trip.startLocation.latitude;
      final endLng = pos?.longitude ?? trip.startLocation.longitude;

      final callable = _functions.httpsCallable('endTrip');
      final res = await callable.call<Map<String, dynamic>>({
        'tripId': tripId,
        'endLat': endLat,
        'endLng': endLng,
      });
      final data = Map<String, dynamic>.from(res.data as Map);

      _stopTracking();

      final completed = TripModel(
        tripId: tripId,
        passengerId: trip.passengerId,
        vehicleId: trip.vehicleId,
        driverUid: trip.driverUid,
        status: TripStatus.completed,
        startLocation: trip.startLocation,
        endLocation: GeoPoint(endLat, endLng),
        startTime: trip.startTime,
        endTime: DateTime.now(),
        distanceKm: (data['distanceKm'] as num).toDouble(),
        baseFare: (data['baseFare'] as num).toDouble(),
        distanceFare: (data['distanceFare'] as num).toDouble(),
        totalFare: (data['totalFare'] as num).toDouble(),
        adults: trip.adults,
        children: trip.children,
      );

      return EndTripResult.success(completed);
    } on FirebaseFunctionsException catch (e) {
      return EndTripResult.failure(e.message ?? 'Could not end trip.');
    } catch (e) {
      return EndTripResult.failure(e.toString());
    }
  }

  Future<TripModel?> getTripById(String id) async {
    final doc = await _db.collection(AppConstants.tripsCol).doc(id).get();
    return doc.exists ? TripModel.fromFirestore(doc) : null;
  }

  // ─── Haversine ────────────────────────────────────────────────
  static double haversineDistance(GeoPoint a, GeoPoint b) {
    const R = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  static double _rad(double deg) => deg * pi / 180;

  void dispose() => _stopTracking();
}

class StartTripResult {
  final bool isSuccess;
  final TripModel? trip;
  final String? error;
  const StartTripResult._({required this.isSuccess, this.trip, this.error});
  factory StartTripResult.success(TripModel t) =>
      StartTripResult._(isSuccess: true, trip: t);
  factory StartTripResult.failure(String e) =>
      StartTripResult._(isSuccess: false, error: e);
}

class EndTripResult {
  final bool isSuccess;
  final TripModel? trip;
  final String? error;
  const EndTripResult._({required this.isSuccess, this.trip, this.error});
  factory EndTripResult.success(TripModel t) =>
      EndTripResult._(isSuccess: true, trip: t);
  factory EndTripResult.failure(String e) =>
      EndTripResult._(isSuccess: false, error: e);
}