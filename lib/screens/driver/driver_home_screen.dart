import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/trip_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/shared_widgets.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _auth = AuthService();
  final _wallet = WalletService();
  final _vehicle = VehicleService();
  final _trips = TripService();
  int _nav = 0;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _auth.userModelStream(),
      builder: (ctx, userSnap) {
        final user = userSnap.data;
        return StreamBuilder<VehicleModel?>(
          stream: _vehicle.driverVehicleStream(),
          builder: (ctx, vSnap) {
            final vehicle = vSnap.data;
            return Scaffold(
              backgroundColor: AppColors.scaffoldBg,
              body: IndexedStack(index: _nav, children: [
                _DashTab(uid: _uid, user: user, vehicle: vehicle,
                    wallet: _wallet, trips: _trips, vehicleService: _vehicle),
                _TripsTab(uid: _uid, trips: _trips),
                _QrTab(vehicle: vehicle),
                _ProfileTab(user: user, auth: _auth),
              ]),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: NavigationBar(
                  selectedIndex: _nav,
                  onDestinationSelected: (i) =>
                      setState(() => _nav = i),
                  backgroundColor: AppColors.white,
                  indicatorColor: AppColors.secondaryLight,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Dashboard'),
                    NavigationDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: 'Trips'),
                    NavigationDestination(
                        icon: Icon(Icons.qr_code_outlined),
                        selectedIcon: Icon(Icons.qr_code),
                        label: 'My QR'),
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
      },
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────
class _DashTab extends StatelessWidget {
  final String uid;
  final UserModel? user;
  final VehicleModel? vehicle;
  final WalletService wallet;
  final TripService trips;
  final VehicleService vehicleService;

  const _DashTab({
    required this.uid, required this.user, required this.vehicle,
    required this.wallet, required this.trips, required this.vehicleService,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Greeting
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Hello, ${user?.name.split(' ').first ?? 'Driver'} 👋',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark),
              ),
              Text(vehicle?.plate ?? 'No vehicle registered',
                  style: const TextStyle(color: AppColors.gray500, fontSize: 14)),
            ]),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.secondaryLight,
              backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? const Icon(Icons.person, color: AppColors.secondary, size: 24)
                  : null,
            ),
          ]),
          const SizedBox(height: 20),

          if (vehicle == null)
            _RegisterBanner(vehicleService: vehicleService),

          // Earnings card
          StreamBuilder<WalletModel>(
            stream: wallet.driverWalletStream(uid),
            builder: (ctx, snap) {
              final w = snap.data;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.secondary, Color(0xFF057A55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Wallet Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    snap.connectionState == ConnectionState.waiting
                        ? '...'
                        : 'KSh ${NumberFormat('#,##0.00').format(w?.balance ?? 0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'All-time earnings: KSh ${NumberFormat('#,##0').format(w?.totalEarned ?? 0)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),

          // Stats
          StreamBuilder<List<TripModel>>(
            stream: trips.driverTripHistoryStream(uid),
            builder: (ctx, snap) {
              final all = snap.data ?? [];
              final now = DateTime.now();

              final todayTrips = all.where((t) =>
                  t.status == TripStatus.completed &&
                  t.startTime.year == now.year &&
                  t.startTime.month == now.month &&
                  t.startTime.day == now.day).toList();

              final weekTrips = all.where((t) =>
                  t.status == TripStatus.completed &&
                  t.startTime.isAfter(now.subtract(const Duration(days: 7)))).toList();

              final todayEarnings = todayTrips.fold<double>(
                  0, (s, t) => s + t.totalFare * (1 - AppConstants.platformFeePercent));

              return Column(children: [
                Row(children: [
                  StatCard(
                    label: "Today's Trips", value: '${todayTrips.length}',
                    icon: Icons.directions_bus_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  StatCard(
                    label: "Today's Earn",
                    value: 'KSh ${todayEarnings.toStringAsFixed(0)}',
                    icon: Icons.trending_up, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  StatCard(
                    label: 'Week Trips', value: '${weekTrips.length}',
                    icon: Icons.calendar_today_outlined, color: AppColors.accent),
                ]),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Recent Trips'),
                const SizedBox(height: 12),

                if (all.isEmpty)
                  const EmptyState(
                    icon: Icons.directions_bus_outlined,
                    title: 'No trips yet',
                    subtitle: 'Share your QR code to start earning.',
                  )
                else
                  ...all.take(5).map((t) => _driverTripTile(t)),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Widget _driverTripTile(TripModel t) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_outline,
                color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.distanceKm.toStringAsFixed(1)} km · ${t.durationText}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.dark)),
              Text(_fmtDate(t.startTime),
                  style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
            ]),
          ),
          Text(
            '+ KSh ${(t.totalFare * (1 - AppConstants.platformFeePercent)).toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 14),
          ),
        ]),
      );

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.day == now.day && dt.month == now.month) return 'Today $time';
    return '${DateFormat('MMM d').format(dt)} $time';
  }
}

// ─── Register Vehicle Banner ──────────────────────────────────────
class _RegisterBanner extends StatelessWidget {
  final VehicleService vehicleService;
  const _RegisterBanner({required this.vehicleService});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.accent),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Register your vehicle to start receiving passengers.',
            style: TextStyle(
                color: AppColors.dark, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: () => _showRegisterDialog(context),
          child: const Text('Register',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    final plateCtrl = TextEditingController();
    final routeCtrl = TextEditingController();
    final stopsCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Register Your Vehicle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Number Plate', hintText: 'e.g. KCB 123A'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: routeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Route', hintText: 'e.g. CBD - Westlands'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stopsCtrl,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Stops (optional)',
                hintText: 'e.g. CBD, Kenyatta, Nyayo, Bunyala, Rongai',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Comma-separated, in order. Shown to passengers as the journey timeline.',
              style: TextStyle(color: AppColors.gray500, fontSize: 12),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (plateCtrl.text.trim().isEmpty ||
                  routeCtrl.text.trim().isEmpty) {
                return;
              }
              final stops = stopsCtrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              await vehicleService.registerVehicle(
                plate: plateCtrl.text.trim(),
                route: routeCtrl.text.trim(),
                stages: stops,
              );

              if (!ctx.mounted) return;

              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

// ─── Trips Tab ────────────────────────────────────────────────────
class _TripsTab extends StatelessWidget {
  final String uid;
  final TripService trips;
  const _TripsTab({required this.uid, required this.trips});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Trip Log',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<TripModel>>(
              stream: trips.driverTripHistoryStream(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No trips yet',
                    subtitle: 'Completed trips will appear here.',
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => TripCard(trip: list[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── QR Tab ───────────────────────────────────────────────────────
class _QrTab extends StatelessWidget {
  final VehicleModel? vehicle;
  const _QrTab({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return const Center(
        child: EmptyState(
          icon: Icons.qr_code,
          title: 'No QR Code Yet',
          subtitle: 'Register your vehicle from the Dashboard to get your QR code.',
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),
          const Text('Your Vehicle QR Code',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          Text('Passengers scan this to board ${vehicle!.plate}',
              style: const TextStyle(color: AppColors.gray500, fontSize: 14)),
          const SizedBox(height: 32),

          // QR card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(children: [
              QrImageView(
                data: vehicle!.qrPayload,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.dark,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 20),
              Text(vehicle!.plate,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 4),
              Text(vehicle!.route,
                  style: const TextStyle(color: AppColors.gray500, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Print or display this QR code where passengers can easily scan it when boarding and alighting.',
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share QR Code'),
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
            backgroundColor: AppColors.secondaryLight,
            backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
            child: user?.avatarUrl == null
                ? const Icon(Icons.person, color: AppColors.secondary, size: 44)
                : null,
          ),
          const SizedBox(height: 14),
          Text(user?.name ?? '',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 4),
          Text(user?.phone ?? '',
              style: const TextStyle(color: AppColors.gray500, fontSize: 14)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Driver',
                style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
          const SizedBox(height: 28),
          _tile(Icons.directions_bus_outlined, 'My Vehicle', () {}),
          _tile(Icons.account_balance_wallet_outlined, 'Earnings History', () {}),
          _tile(Icons.help_outline, 'Help & Support', () {}),
          _tile(Icons.policy_outlined, 'Terms & Privacy', () {}),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
            await auth.signOut();

            if (!context.mounted) return;

            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (_) => false,
            );
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

  Widget _tile(IconData icon, String label, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.secondary, size: 22),
          title: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.gray300, size: 20),
          onTap: onTap,
        ),
      );
}
