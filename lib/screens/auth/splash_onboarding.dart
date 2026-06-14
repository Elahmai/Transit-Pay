import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

// ─── Splash ───────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      final model = await AuthService().getCurrentUserModel();
      if (!mounted) return;
      if (model == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else if (model.isDriver) {
        Navigator.pushReplacementNamed(context, AppRoutes.driverHome);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.passengerHome);
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.directions_bus_filled,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 20),
                const Text('Transit Pay',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Smart bus payments for Kenya',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
              ]),
            ),
          ),
        ),
      );
}

// ─── Onboarding ───────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _pages = const [
    _Page(icon: Icons.qr_code_scanner, color: AppColors.primary,
        title: 'Tap to Board',
        subtitle: 'Scan the QR code inside any matatu to start your journey instantly.'),
    _Page(icon: Icons.auto_mode, color: AppColors.secondary,
        title: 'Auto Pay',
        subtitle: 'Scan again when you alight. Your fare is calculated automatically.'),
    _Page(icon: Icons.money_off, color: AppColors.accent,
        title: 'No Cash Needed',
        subtitle: 'Top up via M-Pesa and never worry about loose change again.'),
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text('Skip',
                    style: TextStyle(color: AppColors.gray500)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.gray300,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  if (_page < _pages.length - 1) {
                    _ctrl.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
                child: Text(_page < _pages.length - 1 ? 'Next' : 'Get Started'),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      );
}

class _Page extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Page({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(36)),
            child: Icon(icon, color: color, size: 72),
          ),
          const SizedBox(height: 40),
          Text(title,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 14),
          Text(subtitle,
              style: const TextStyle(fontSize: 16, color: AppColors.gray500, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      );
}
