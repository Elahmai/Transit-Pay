import 'package:cloud_firestore/cloud_firestore.dart';

// ─── UserModel ────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String phone;
  final String name;
  final String? avatarUrl;
  final String role; // 'passenger' | 'driver'
  final bool isActive;
  final DateTime createdAt;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.phone,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.fcmToken,
  });

  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phone: d['phone'] ?? '',
      name: d['name'] ?? '',
      avatarUrl: d['avatarUrl'],
      role: d['role'] ?? 'passenger',
      isActive: d['isActive'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: d['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'phone': phone,
        'name': name,
        'avatarUrl': avatarUrl,
        'role': role,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'fcmToken': fcmToken,
      };
}

// ─── WalletModel ──────────────────────────────────────────────────
class WalletModel {
  final String uid;
  final double balance;
  final double totalTopUp;
  final double totalEarned;

  const WalletModel({
    required this.uid,
    required this.balance,
    this.totalTopUp = 0,
    this.totalEarned = 0,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WalletModel(
      uid: doc.id,
      balance: (d['balance'] ?? 0).toDouble(),
      totalTopUp: (d['totalTopUp'] ?? 0).toDouble(),
      totalEarned: (d['totalEarned'] ?? 0).toDouble(),
    );
  }
}

// ─── VehicleModel ─────────────────────────────────────────────────
class VehicleModel {
  final String vehicleId;
  final String ownerUid;
  final String plate;
  final String route;
  final String qrPayload;
  final bool isActive;
  final List<String> stages;

  const VehicleModel({
    required this.vehicleId,
    required this.ownerUid,
    required this.plate,
    required this.route,
    required this.qrPayload,
    this.isActive = true,
    this.stages = const [],
  });

  /// Stops to show on the journey timeline. Falls back to splitting the
  /// free-text `route` (e.g. "CBD - Rongai") when no explicit stage list
  /// was provided at registration, so older vehicles still render a stub
  /// origin -> destination timeline.
  List<String> get displayStages {
    if (stages.isNotEmpty) return stages;
    return route
        .split(RegExp(r'[-–—>→]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VehicleModel(
      vehicleId: doc.id,
      ownerUid: d['ownerUid'] ?? '',
      plate: d['plate'] ?? '',
      route: d['route'] ?? '',
      qrPayload: d['qrPayload'] ?? '',
      isActive: d['isActive'] ?? true,
      stages: List<String>.from(d['stages'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'ownerUid': ownerUid,
        'plate': plate,
        'route': route,
        'qrPayload': qrPayload,
        'isActive': isActive,
        'stages': stages,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ─── TripModel ────────────────────────────────────────────────────
enum TripStatus { active, completed, failed, processing }

class TripModel {
  final String tripId;
  final String passengerId;
  final String vehicleId;
  final String driverUid;
  final TripStatus status;
  final GeoPoint startLocation;
  final GeoPoint? endLocation;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double baseFare;
  final double distanceFare;
  final double totalFare;
  final List<GeoPoint> locationHistory;
  final int adults;
  final int children;
  static const double childFarePercent = 0.5; // 50% discount

  const TripModel({
    required this.tripId,
    required this.passengerId,
    required this.vehicleId,
    required this.driverUid,
    required this.status,
    required this.startLocation,
    this.endLocation,
    required this.startTime,
    this.endTime,
    this.distanceKm = 0,
    this.baseFare = 20,
    this.distanceFare = 0,
    this.totalFare = 0,
    this.locationHistory = const [],
    this.adults = 1,
    this.children = 0,
  });

  int get totalPassengers => adults + children;

  /// Estimated fare considering group + child discount
  double get estimatedFare {
    final perKm = distanceKm * 3.0;
    final adultFare = adults * (baseFare + perKm);
    final childFare = children * (baseFare + perKm) * childFarePercent;
    return adultFare + childFare;
  }

  String get durationText {
    final diff = (endTime ?? DateTime.now()).difference(startTime);
    final m = diff.inMinutes;
    if (m < 60) return '${m}min';
    return '${diff.inHours}h ${m % 60}min';
  }

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    TripStatus status;
    switch (d['status']) {
      case 'active': status = TripStatus.active; break;
      case 'completed': status = TripStatus.completed; break;
      case 'failed': status = TripStatus.failed; break;
      default: status = TripStatus.processing;
    }
    return TripModel(
      tripId: doc.id,
      passengerId: d['passengerId'] ?? '',
      vehicleId: d['vehicleId'] ?? '',
      driverUid: d['driverUid'] ?? '',
      status: status,
      startLocation: d['startLocation'] ?? const GeoPoint(0, 0),
      endLocation: d['endLocation'],
      startTime: (d['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (d['endTime'] as Timestamp?)?.toDate(),
      distanceKm: (d['distanceKm'] ?? 0).toDouble(),
      baseFare: (d['baseFare'] ?? 20).toDouble(),
      distanceFare: (d['distanceFare'] ?? 0).toDouble(),
      totalFare: (d['totalFare'] ?? 0).toDouble(),
      locationHistory: List<GeoPoint>.from(d['locationHistory'] ?? []),
      adults: (d['adults'] ?? 1) as int,
      children: (d['children'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'tripId': tripId,
        'passengerId': passengerId,
        'vehicleId': vehicleId,
        'driverUid': driverUid,
        'status': status.name,
        'startLocation': startLocation,
        'endLocation': endLocation,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'distanceKm': distanceKm,
        'baseFare': baseFare,
        'distanceFare': distanceFare,
        'totalFare': totalFare,
        'locationHistory': locationHistory,
        'adults': adults,
        'children': children,
      };
}

// ─── TransactionModel ─────────────────────────────────────────────
enum TransactionType { topup, fareDebit, fareCredit }

class TransactionModel {
  final String transactionId;
  final String uid;
  final TransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? tripId;
  final String? mpesaRef;
  final String status;
  final DateTime timestamp;
  final String description;

  const TransactionModel({
    required this.transactionId,
    required this.uid,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.tripId,
    this.mpesaRef,
    required this.status,
    required this.timestamp,
    required this.description,
  });

  bool get isCredit =>
      type == TransactionType.topup || type == TransactionType.fareCredit;

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    TransactionType type;
    switch (d['type']) {
      case 'topup': type = TransactionType.topup; break;
      case 'fare_credit': type = TransactionType.fareCredit; break;
      default: type = TransactionType.fareDebit;
    }
    return TransactionModel(
      transactionId: doc.id,
      uid: d['uid'] ?? '',
      type: type,
      amount: (d['amount'] ?? 0).toDouble(),
      balanceBefore: (d['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (d['balanceAfter'] ?? 0).toDouble(),
      tripId: d['tripId'],
      mpesaRef: d['mpesaRef'],
      status: d['status'] ?? 'success',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: d['description'] ?? '',
    );
  }
}