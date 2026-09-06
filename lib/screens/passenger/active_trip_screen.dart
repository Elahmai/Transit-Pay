import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/shared_widgets.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});
  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  GoogleMapController? _mapCtrl;
  StreamSubscription? _sub;
  TripModel? _trip;
  bool _initialized = false;
  List<LatLng> _poly = [];

  // Passenger counters (editable during active trip)
  int _adults = 1;
  int _children = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _trip = ModalRoute.of(context)!.settings.arguments as TripModel;
      _adults = _trip!.adults;
      _children = _trip!.children;
      _initialized = true;
      _subscribe();
    }
  }

  void _subscribe() {
    _sub = FirebaseFirestore.instance
        .collection('trips')
        .doc(_trip!.tripId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final updated = TripModel.fromFirestore(doc);
      setState(() {
        _trip = updated;
        _poly = updated.locationHistory
            .map((g) => LatLng(g.latitude, g.longitude))
            .toList();
      });
      if (updated.status == TripStatus.completed) {
        _sub?.cancel();
        Navigator.pushReplacementNamed(context, AppRoutes.tripSummary,
            arguments: updated);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

// Save passenger counts to Firestore
Future<void> _updatePassengerCount() async {
  await FirebaseFirestore.instance
      .collection('trips')
      .doc(_trip!.tripId)
      .update({'adults': _adults, 'children': _children});

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Updated: $_adults adult${_adults != 1 ? 's' : ''}, '
        '$_children child${_children != 1 ? 'ren' : ''}',
      ),
      backgroundColor: AppColors.secondary,
      duration: const Duration(seconds: 2),
    ),
  );
}

  void _showPassengerSelector() {
    int tempAdults = _adults;
    int tempChildren = _children;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            const Text('Passengers',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
            const SizedBox(height: 6),
            const Text('Select number of adults and children',
                style: TextStyle(color: AppColors.gray500, fontSize: 14)),
            const SizedBox(height: 24),

            // Adults row
            _passengerRow(
              icon: Icons.person,
              color: AppColors.primary,
              label: 'Adults',
              sublabel: 'Full fare',
              count: tempAdults,
              onDecrement: tempAdults > 1
                  ? () => setSheetState(() => tempAdults--)
                  : null,
              onIncrement: tempAdults < 10
                  ? () => setSheetState(() => tempAdults++)
                  : null,
            ),
            const SizedBox(height: 16),

            // Children row
            _passengerRow(
              icon: Icons.child_care,
              color: AppColors.secondary,
              label: 'Children',
              sublabel: 'Under 10 · 50% off',
              count: tempChildren,
              onDecrement: tempChildren > 0
                  ? () => setSheetState(() => tempChildren--)
                  : null,
              onIncrement: tempChildren < 10
                  ? () => setSheetState(() => tempChildren++)
                  : null,
            ),
            const SizedBox(height: 20),

            // Fare preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _farePreviewRow(
                    '$tempAdults Adult${tempAdults != 1 ? 's' : ''}',
                    'Full fare × $tempAdults',
                    AppColors.primary),
                if (tempChildren > 0) ...[
                  const SizedBox(height: 6),
                  _farePreviewRow(
                      '$tempChildren Child${tempChildren != 1 ? 'ren' : ''}',
                      '50% fare × $tempChildren',
                      AppColors.secondary),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Est. Total Fare',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                            fontSize: 14)),
                    Text(
                      'KSh ${_calcEstimate(tempAdults, tempChildren).toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 16),
                    ),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _adults = tempAdults;
                  _children = tempChildren;
                });
                Navigator.pop(ctx);
                _updatePassengerCount();
              },
              child: const Text('Confirm Passengers'),
            ),
          ]),
        ),
      ),
    );
  }

  double _calcEstimate(int adults, int children) {
    if (_trip == null) return 0;
    final km = _trip!.distanceKm;
    const base = AppConstants.baseFare;
    final perKm = km * AppConstants.ratePerKm;
    return adults * (base + perKm) + children * (base + perKm) * 0.5;
  }

  Widget _passengerRow({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required int count,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
  }) =>
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.dark)),
            Text(sublabel,
                style: const TextStyle(
                    color: AppColors.gray500, fontSize: 12)),
          ]),
        ),
        // Counter
        Row(children: [
          _counterBtn(Icons.remove, onDecrement),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
          ),
          _counterBtn(Icons.add, onIncrement),
        ]),
      ]);

  Widget _counterBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: onTap != null ? AppColors.primary : AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: onTap != null ? Colors.white : AppColors.gray300,
              size: 16),
        ),
      );

  Widget _farePreviewRow(String label, String sub, Color color) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: color)),
        Text(sub,
            style: const TextStyle(
                color: AppColors.gray500, fontSize: 12)),
      ]);

  LatLng get _startLatLng =>
      LatLng(_trip!.startLocation.latitude, _trip!.startLocation.longitude);

  LatLng get _currentLatLng =>
      _poly.isNotEmpty ? _poly.last : _startLatLng;

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return const Scaffold(body: AppLoader(message: 'Loading trip...'));
    }

    final estimatedFare = _calcEstimate(_adults, _children);
    final totalPax = _adults + _children;

    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────
        GoogleMap(
          onMapCreated: (ctrl) {
            _mapCtrl = ctrl;
            ctrl.animateCamera(
                CameraUpdate.newLatLngZoom(_startLatLng, 14));
          },
          initialCameraPosition:
              CameraPosition(target: _startLatLng, zoom: 14),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('start'),
              position: _startLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Trip Start'),
            ),
            if (_poly.length > 1)
              Marker(
                markerId: const MarkerId('current'),
                position: _currentLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow: const InfoWindow(title: 'You are here'),
              ),
          },
          polylines: {
            if (_poly.length > 1)
              Polyline(
                polylineId: const PolylineId('route'),
                points: _poly,
                color: AppColors.primary,
                width: 5,
              ),
          },
        ),

        // ── Top bar ───────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _mapBtn(Icons.arrow_back_ios, () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6)
                      ]),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('Active · ${_trip!.vehicleId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.dark)),
                    const Spacer(),
                    // Passenger badge
                    GestureDetector(
                      onTap: _showPassengerSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.people,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text('$totalPax',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              _mapBtn(Icons.my_location, () {
                _mapCtrl?.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLatLng, 15));
              }),
            ]),
          ),
        ),

        // ── Bottom card ───────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20,
                    offset: Offset(0, -4))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2)),
              ),

              // Stats row
              Row(children: [
                StatCard(
                  label: 'Distance',
                  value: '${_trip!.distanceKm.toStringAsFixed(1)} km',
                  icon: Icons.route,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Est. Fare',
                  value: 'KSh ${estimatedFare.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Duration',
                  value: _trip!.durationText,
                  icon: Icons.timer_outlined,
                  color: AppColors.accent,
                ),
              ]),
              const SizedBox(height: 12),

              // Passenger summary tap to edit
              GestureDetector(
                onTap: _showPassengerSelector,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray300),
                  ),
                  child: Row(children: [
                    const Icon(Icons.people_outline,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.gray700),
                          children: [
                            TextSpan(
                              text: '$_adults adult${_adults != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark),
                            ),
                            if (_children > 0)
                              TextSpan(
                                text:
                                    ' + $_children child${_children != 1 ? 'ren' : ''} (50% off)',
                                style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                        color: AppColors.primary, size: 16),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                    context, AppRoutes.scanQr,
                    arguments: _trip!),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan to End Trip & Pay'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(double.infinity, 52)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan the QR code inside the matatu when you alight',
                style: TextStyle(color: AppColors.gray500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)
            ],
          ),
          child: Icon(icon, size: 18, color: AppColors.dark),
        ),
      );
}