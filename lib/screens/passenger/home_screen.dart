import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/trip_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/shared_widgets.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});
  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _auth = AuthService();
  final _wallet = WalletService();
  final _trips = TripService();
  int _nav = 0;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _auth.userModelStream(),
      builder: (ctx, userSnap) {
        final user = userSnap.data;
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: IndexedStack(index: _nav, children: [
            _HomeTab(uid: _uid, user: user, wallet: _wallet, trips: _trips),
            _HistoryTab(uid: _uid, trips: _trips),
            _ProfileTab(user: user, auth: _auth),
          ]),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: NavigationBar(
              selectedIndex: _nav,
              onDestinationSelected: (i) => setState(() => _nav = i),
              backgroundColor: AppColors.white,
              indicatorColor: AppColors.primaryLight,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: 'History'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String uid;
  final UserModel? user;
  final WalletService wallet;
  final TripService trips;
  const _HomeTab(
      {required this.uid,
      required this.user,
      required this.wallet,
      required this.trips});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Greeting
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Hello, ${user?.name.split(' ').first ?? 'Rider'} 👋',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark),
                ),
                const Text('Ready to ride?',
                    style:
                        TextStyle(color: AppColors.gray500, fontSize: 14)),
              ]),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? const Icon(Icons.person,
                        color: AppColors.primary, size: 24)
                    : null,
              ),
            ]),
            const SizedBox(height: 24),

            // Wallet
            StreamBuilder<WalletModel>(
              stream: wallet.passengerWalletStream(uid),
              builder: (ctx, snap) => WalletCard(
                balance: snap.data?.balance ?? 0,
                isLoading:
                    snap.connectionState == ConnectionState.waiting,
                onTopUp: () =>
                    Navigator.pushNamed(context, AppRoutes.topUp),
              ),
            ),
            const SizedBox(height: 20),

            // Active trip banner
            StreamBuilder<TripModel?>(
              stream: trips.activeTripStream(uid),
              builder: (ctx, snap) {
                final active = snap.data;
                if (active == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, AppRoutes.activeTrip,
                      arguments: active),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.secondary, width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Trip in Progress',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary,
                                      fontSize: 14)),
                              Text(
                                '${active.distanceKm.toStringAsFixed(1)} km · KSh ${active.estimatedFare.toStringAsFixed(0)} est.',
                                style: const TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 12)),
                            ]),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.secondary),
                    ]),
                  ),
                );
              },
            ),

            // Scan CTA
            StreamBuilder<TripModel?>(
              stream: trips.activeTripStream(uid),
              builder: (ctx, snap) {
                final hasActive = snap.data != null;
                return ElevatedButton.icon(
                  onPressed: () {
                    if (hasActive) {
                      Navigator.pushNamed(context, AppRoutes.activeTrip,
                          arguments: snap.data!);
                    } else {
                      Navigator.pushNamed(context, AppRoutes.scanQr);
                    }
                  },
                  icon: Icon(hasActive
                      ? Icons.map_outlined
                      : Icons.qr_code_scanner),
                  label: Text(
                      hasActive ? 'View Active Trip' : 'Scan to Ride'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor:
                        hasActive ? AppColors.secondary : AppColors.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recent trips
            const SectionHeader(title: 'Recent Trips'),
            const SizedBox(height: 12),
            StreamBuilder<List<TripModel>>(
              stream: trips.passengerTripHistoryStream(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.directions_bus_outlined,
                    title: 'No trips yet',
                    subtitle:
                        'Scan a QR code inside a matatu to start your first trip.',
                  );
                }
                return Column(
                  children: list
                      .take(3)
                      .map((t) => TripCard(
                            trip: t,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.tripSummary,
                                arguments: t),
                          ))
                      .toList(),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final String uid;
  final TripService trips;
  const _HistoryTab({required this.uid, required this.trips});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Trip History',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<TripModel>>(
              stream: trips.passengerTripHistoryStream(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No trips yet',
                    subtitle: 'Your trip history will appear here.',
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => TripCard(
                    trip: list[i],
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.tripSummary,
                        arguments: list[i]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final UserModel? user;
  final AuthService auth;
  const _ProfileTab({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryLight,
            backgroundImage:
                user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
            child: user?.avatarUrl == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 44)
                : null,
          ),
          const SizedBox(height: 14),
          Text(user?.name ?? '',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
          const SizedBox(height: 4),
          Text(user?.phone ?? '',
              style:
                  const TextStyle(color: AppColors.gray500, fontSize: 14)),
          const SizedBox(height: 28),
          _tile(context, Icons.account_balance_wallet_outlined,
              'Top Up Wallet',
              () => Navigator.pushNamed(context, AppRoutes.topUp)),
          _tile(context, Icons.history, 'Trip History', () {}),
          _tile(context, Icons.notifications_outlined, 'Notifications', () {}),
          _tile(context, Icons.help_outline, 'Help & Support', () {}),
          _tile(context, Icons.info_outline, 'About Transit Pay', () {}),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error)),
          ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label,
          VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary, size: 22),
          title: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.gray300, size: 20),
          onTap: onTap,
        ),
      );
}
