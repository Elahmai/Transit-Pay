import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF1040B0);
  static const primaryLight = Color(0xFFEBF5FB);
  static const secondary = Color(0xFF0E9F6E);
  static const secondaryLight = Color(0xFFEAFAF1);
  static const accent = Color(0xFFFF5A1F);
  static const accentLight = Color(0xFFFFF3EE);
  static const dark = Color(0xFF1E2A3A);
  static const gray900 = Color(0xFF111827);
  static const gray700 = Color(0xFF374151);
  static const gray500 = Color(0xFF6B7280);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray100 = Color(0xFFF3F4F6);
  static const white = Color(0xFFFFFFFF);
  static const error = Color(0xFFE02424);
  static const warning = Color(0xFFFF8A00);
  static const success = Color(0xFF0E9F6E);
  static const scaffoldBg = Color(0xFFF8F9FA);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.white,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.dark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.dark,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.gray300, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.gray300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1),
          ),
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.gray500,
            fontSize: 14,
          ),
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.gray300,
            fontSize: 14,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.gray100,
          selectedColor: AppColors.primaryLight,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}

class AppConstants {
  static const double baseFare = 20.0; // KSh
  static const double ratePerKm = 3.0; // KSh per km
  static const double minimumBalance = 20.0; // KSh
  static const double platformFeePercent = 0.05; // 5%
  static const int locationUpdateIntervalSecs = 10;
  static const String currency = 'KSh';

  // Firestore collections
  static const String usersCol = 'users';
  static const String vehiclesCol = 'vehicles';
  static const String tripsCol = 'trips';
  static const String transactionsCol = 'transactions';
  static const String passengerWalletsCol = 'passengerWallets';
  static const String driverWalletsCol = 'driverWallets';
  static const String notificationsCol = 'notifications';
  static const String configCol = 'config';
}

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String roleSelect = '/role-select';
  static const String passengerHome = '/passenger/home';
  static const String topUp = '/passenger/top-up';
  static const String scanQr = '/passenger/scan-qr';
  static const String activeTrip = '/passenger/active-trip';
  static const String tripSummary = '/passenger/trip-summary';
  static const String tripHistory = '/passenger/history';
  static const String passengerProfile = '/passenger/profile';
  static const String driverHome = '/driver/home';
  static const String driverQr = '/driver/qr';
  static const String driverTrips = '/driver/trips';
  static const String driverProfile = '/driver/profile';
}