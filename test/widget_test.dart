import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pay/screens/auth/splash_onboarding.dart';
import 'package:transit_pay/utils/theme.dart'; // for AppRoutes

void main() {
  testWidgets('Transit-Pay splash navigates to onboarding when logged out',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.onboarding: (_) => const Scaffold(body: Text('Onboarding')),
        },
        home: SplashScreen(
          getCurrentUser: () => null,       // simulate logged-out, no Firebase needed
          splashDuration: Duration.zero,    // skip the 2s wait
        ),
      ),
    );

    await tester.pump();          // build first frame
    await tester.pump();          // let Future.delayed(Duration.zero) resolve
    await tester.pumpAndSettle(); // settle the route transition

    expect(find.text('Onboarding'), findsOneWidget);
  });
}