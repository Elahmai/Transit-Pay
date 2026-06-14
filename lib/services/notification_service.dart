import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(android: android, iOS: ios));
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) _show(title: n.title ?? 'Transit Pay', body: n.body ?? '');
    });
  }

  Future<void> _show({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'transit_pay',
      'Transit Pay',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showTripStarted(String plate) =>
      _show(title: '🚍 Trip Started', body: 'You boarded $plate. Safe travels!');

  Future<void> showTripEnded(double fare, double km) =>
      _show(
        title: '✅ Trip Completed',
        body: 'KSh ${fare.toStringAsFixed(0)} deducted for ${km.toStringAsFixed(1)} km.',
      );

  Future<void> showTopUpSuccess(double amount) =>
      _show(
        title: '💰 Top-Up Successful',
        body: 'KSh ${amount.toStringAsFixed(0)} added to your wallet.',
      );

  Future<void> showLowBalance(double balance) =>
      _show(
        title: '⚠️ Low Balance',
        body: 'Your wallet has KSh ${balance.toStringAsFixed(0)}. Top up to keep riding.',
      );
}
