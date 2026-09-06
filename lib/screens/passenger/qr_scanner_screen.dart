import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/vehicle_service.dart';
import '../../services/trip_service.dart';
import '../../services/notification_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../widgets/shared_widgets.dart';

enum _ScanMode { startTrip, endTrip }

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _vehicleService = VehicleService();
  final _tripService = TripService();
  final _notif = NotificationService();
  final _camCtrl = MobileScannerController();

  bool _processing = false, _torchOn = false, _initialized = false;
  _ScanMode _mode = _ScanMode.startTrip;
  TripModel? _activeTrip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is TripModel) {
        _activeTrip = args;
        _mode = _ScanMode.endTrip;
      }
      _initialized = true;
    }
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _processing = true);
    _camCtrl.stop();
    _mode == _ScanMode.startTrip
        ? await _handleStart(raw)
        : await _handleEnd(raw);
  }

  Future<void> _handleStart(String raw) async {
    final result = await _vehicleService.validateQrCode(raw);
    if (!result.isSuccess) { _showError(result.error!); return; }

    final confirmed = await _confirmBoard(result.vehicle!);
    if (!confirmed) {
      setState(() => _processing = false);
      _camCtrl.start();
      return;
    }

    final start = await _tripService.startTrip(result.vehicle!);
    if (!mounted) return;
    if (start.isSuccess) {
      await _notif.showTripStarted(result.vehicle!.plate);
       if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.activeTrip,
          arguments: start.trip!);
    } else {
      _showError(start.error!);
    }
  }

  Future<void> _handleEnd(String raw) async {
    if (_activeTrip == null) { _showError('No active trip found.'); return; }
    String scannedId;
    try {
      final m = RegExp(r'"vehicleId"\s*:\s*"([^"]+)"').firstMatch(raw);
      scannedId = m?.group(1) ?? raw.trim();
    } catch (_) {
      scannedId = raw.trim();
    }

    final result = await _tripService.endTrip(
        tripId: _activeTrip!.tripId, scannedVehicleId: scannedId);
    if (!mounted) return;
    if (result.isSuccess) {
      await _notif.showTripEnded(
          result.trip!.totalFare, result.trip!.distanceKm);
           if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.tripSummary,
          arguments: result.trip!);
    } else {
      _showError(result.error!);
    }
  }

  Future<bool> _confirmBoard(VehicleModel v) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.directions_bus_filled,
                    color: AppColors.primary, size: 30),
              ),
              const SizedBox(height: 14),
              Text(v.plate,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark)),
              const SizedBox(height: 4),
              Text(v.route,
                  style: const TextStyle(
                      color: AppColors.gray500, fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _fareRow('Base Fare',
                      'KSh ${AppConstants.baseFare.toStringAsFixed(0)}'),
                  const SizedBox(height: 4),
                  _fareRow('Rate',
                      'KSh ${AppConstants.ratePerKm.toStringAsFixed(0)}/km'),
                ]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Board This Matatu')),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.gray500))),
            ]),
          ),
        ) ??
        false;
  }

  Widget _fareRow(String l, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l,
              style: const TextStyle(
                  color: AppColors.gray500, fontSize: 13)),
          Text(v,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                  fontSize: 13)),
        ],
      );

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _processing = false);
    _camCtrl.start();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4)));
  }

  @override
  void dispose() { _camCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(controller: _camCtrl, onDetect: _onScan),
        CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _OverlayPainter()),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _iconBtn(Icons.arrow_back_ios,
                      () => Navigator.pop(context)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: _mode == _ScanMode.startTrip
                            ? AppColors.primary
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        _mode == _ScanMode.startTrip
                            ? '🚍 Start Trip'
                            : '🏁 End Trip',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                  _iconBtn(
                      _torchOn ? Icons.flash_off : Icons.flash_on, () {
                    setState(() => _torchOn = !_torchOn);
                    _camCtrl.toggleTorch();
                  }),
                ]),
          ),
        ),

        // Instructions below scan box
        Align(
          alignment: const Alignment(0, 0.55),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _mode == _ScanMode.startTrip
                  ? 'Scan the QR code inside the matatu'
                  : 'Scan QR to end your trip & pay',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _mode == _ScanMode.startTrip
                  ? 'Point camera at the QR on the seat or door'
                  : 'Use the same QR you scanned to board',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ]),
        ),

        if (_processing)
          Container(
            color: Colors.black.withValues(alpha: 0.65),
            child: const AppLoader(message: 'Processing...'),
          ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

// ─── Scan overlay painter ─────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const sq = 250.0;
    final l = (size.width - sq) / 2;
    final t = (size.height - sq) / 2 - 30;

    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(l, t, sq, sq), const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const c = 28.0;
    // TL
    canvas.drawLine(Offset(l, t + c), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + c, t), p);
    // TR
    canvas.drawLine(Offset(l + sq - c, t), Offset(l + sq, t), p);
    canvas.drawLine(Offset(l + sq, t), Offset(l + sq, t + c), p);
    // BR
    canvas.drawLine(
        Offset(l + sq, t + sq - c), Offset(l + sq, t + sq), p);
    canvas.drawLine(
        Offset(l + sq, t + sq), Offset(l + sq - c, t + sq), p);
    // BL
    canvas.drawLine(Offset(l, t + sq - c), Offset(l, t + sq), p);
    canvas.drawLine(Offset(l, t + sq), Offset(l + c, t + sq), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
