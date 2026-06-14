import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/splash_onboarding.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/passenger/topup_screen.dart';
import 'screens/passenger/qr_scanner_screen.dart';
import 'screens/passenger/active_trip_screen.dart';
import 'screens/passenger/trip_summary_screen.dart';
import 'screens/driver/driver_home_screen.dart';
// ignore: unused_import
import 'services/notification_service.dart';
import 'utils/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const TransitPayApp());
}

class TransitPayApp extends StatelessWidget {
  const TransitPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transit Pay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash:        (_) => const SplashScreen(),
        AppRoutes.onboarding:    (_) => const OnboardingScreen(),
        AppRoutes.login:         (_) => const LoginScreen(),
        AppRoutes.roleSelect:    (_) => const RoleSelectScreen(),
        AppRoutes.passengerHome: (_) => const PassengerHomeScreen(),
        AppRoutes.topUp:         (_) => const TopUpScreen(),
        AppRoutes.scanQr:        (_) => const QrScannerScreen(),
        AppRoutes.activeTrip:    (_) => const ActiveTripScreen(),
        AppRoutes.tripSummary:   (_) => const TripSummaryScreen(),
        AppRoutes.driverHome:    (_) => const DriverHomeScreen(),
      },
    );
  }
}
