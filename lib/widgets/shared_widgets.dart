import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../utils/theme.dart';

// ─── Wallet Card ──────────────────────────────────────────────────
class WalletCard extends StatelessWidget {
  final double balance;
  final bool isLoading;
  final VoidCallback? onTopUp;
  const WalletCard(
      {super.key, required this.balance, this.isLoading = false, this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Wallet Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('KSh',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        isLoading
            ? Shimmer.fromColors(
                baseColor: Colors.white24,
                highlightColor: Colors.white38,
                child: Container(
                    width: 160,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8))))
            : Text(
                NumberFormat('#,##0.00').format(balance),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1),
              ),
        const SizedBox(height: 20),
        if (onTopUp != null)
          GestureDetector(
            onTap: onTopUp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Top Up',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ─── Trip Card ────────────────────────────────────────────────────
class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;
  const TripCard({super.key, required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = trip.status == TripStatus.completed
        ? AppColors.success
        : trip.status == TripStatus.active
            ? AppColors.primary
            : AppColors.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
              trip.status == TripStatus.completed
                  ? Icons.check_circle_outline
                  : trip.status == TripStatus.active
                      ? Icons.directions_bus
                      : Icons.cancel_outlined,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.vehicleId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.dark)),
              const SizedBox(height: 3),
              Text(DateFormat('MMM d, y · h:mm a').format(trip.startTime),
                  style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.route, size: 12, color: AppColors.gray500),
                const SizedBox(width: 3),
                Text(
                    '${trip.distanceKm.toStringAsFixed(1)} km · ${trip.durationText}',
                    style: const TextStyle(
                        color: AppColors.gray500, fontSize: 12)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              trip.status == TripStatus.completed
                  ? 'KSh ${trip.totalFare.toStringAsFixed(0)}'
                  : trip.status == TripStatus.active
                      ? 'Active'
                      : 'Failed',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: statusColor),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(trip.status.name,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(transaction.description,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.dark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(DateFormat('MMM d · h:mm a').format(transaction.timestamp),
                style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
          ]),
        ),
        Text('${isCredit ? '+' : '-'} KSh ${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: color)),
      ]),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── Amount Selector ──────────────────────────────────────────────
class AmountSelector extends StatelessWidget {
  final double? selected;
  final Function(double) onSelect;
  final List<double> amounts;
  const AmountSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.amounts = const [50, 100, 200, 500, 1000],
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: amounts
            .map((a) => GestureDetector(
                  onTap: () => onSelect(a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected == a ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected == a
                            ? AppColors.primary
                            : AppColors.gray300,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'KSh ${a.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected == a
                              ? AppColors.white
                              : AppColors.gray700),
                    ),
                  ),
                ))
            .toList(),
      );
}

// ─── Section Header ───────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.dark)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
        ],
      );
}

// ─── App Loader ───────────────────────────────────────────────────
class AppLoader extends StatelessWidget {
  final String? message;
  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!,
                style: const TextStyle(color: AppColors.gray500, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ]),
      );
}

// ─── Empty State ──────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: AppColors.gray300, size: 40),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.dark)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: AppColors.gray500, fontSize: 14),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}
