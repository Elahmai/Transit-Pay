import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trip =
        ModalRoute.of(context)!.settings.arguments as TripModel;
    final done = trip.status == TripStatus.completed;
    // ignore: unused_local_variable
    final statusColor = done ? AppColors.secondary : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(done ? 'Trip Receipt' : 'Trip Details'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.passengerHome, (_) => false),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: done
                    ? [AppColors.secondary, const Color(0xFF057A55)]
                    : [AppColors.error, const Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Icon(done ? Icons.check_circle : Icons.cancel,
                  color: Colors.white, size: 52),
              const SizedBox(height: 12),
              Text(done ? 'Trip Completed!' : 'Trip Failed',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              if (done) ...[
                const SizedBox(height: 6),
                Text(
                  'KSh ${trip.totalFare.toStringAsFixed(2)} deducted',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // Receipt
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Trip Details',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.dark)),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            _row('Vehicle', trip.vehicleId),
            _row('Date', DateFormat('EEE, MMM d, y').format(trip.startTime)),
            _row('Departure', DateFormat('h:mm a').format(trip.startTime)),
            if (trip.endTime != null)
              _row('Arrival', DateFormat('h:mm a').format(trip.endTime!)),
            _row('Duration', trip.durationText),
            _row('Distance', '${trip.distanceKm.toStringAsFixed(2)} km'),
            _row('Passengers',
                '${trip.adults} adult${trip.adults != 1 ? 's' : ''}${trip.children > 0 ? ' + ${trip.children} child${trip.children != 1 ? 'ren' : ''} (50% off)' : ''}'),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            const Text('Fare Breakdown',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.dark)),
            const SizedBox(height: 10),
            _row('Adults (${trip.adults}) base fare',
                'KSh ${(trip.adults * trip.baseFare).toStringAsFixed(2)}'),
            if (trip.children > 0)
              _row('Children (${trip.children}) 50% off',
                  'KSh ${(trip.children * trip.baseFare * 0.5).toStringAsFixed(2)}'),
            _row(
                'Distance (${trip.distanceKm.toStringAsFixed(1)} km × KSh ${AppConstants.ratePerKm.toStringAsFixed(0)})',
                'KSh ${trip.distanceFare.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Fare',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.dark)),
                Text('KSh ${trip.totalFare.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.primary)),
              ],
            ),
          ])),
          const SizedBox(height: 16),

          // Trip ID chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.gray500, size: 16),
              const SizedBox(width: 8),
              Text(
                'Trip ID: ${trip.tripId.length > 12 ? trip.tripId.substring(0, 12) : trip.tripId}...',
                style: const TextStyle(
                    color: AppColors.gray500,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Actions
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.passengerHome, (_) => false),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.scanQr),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start Another Trip'),
          ),
        ]),
      ),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(l,
                  style: const TextStyle(
                      color: AppColors.gray500, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.dark)),
          ],
        ),
      );
}