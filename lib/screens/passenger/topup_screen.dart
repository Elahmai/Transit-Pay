import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/wallet_service.dart';
import '../../services/notification_service.dart';
import '../../utils/theme.dart';
import '../../widgets/shared_widgets.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _wallet = WalletService();
  final _notif = NotificationService();
  final _customCtrl = TextEditingController();
  double? _selected;
  bool _loading = false, _showCustom = false;

  @override
  void dispose() { _customCtrl.dispose(); super.dispose(); }

  Future<void> _processTopUp() async {
    final amount =
        _showCustom ? double.tryParse(_customCtrl.text.trim()) : _selected;
    if (amount == null || amount <= 0) {
      _snack('Please select or enter an amount');
      return;
    }
    setState(() => _loading = true);
    final confirmed = await _showStkDialog(amount);
    if (!confirmed) { setState(() => _loading = false); return; }

    final result = await _wallet.simulateTopUp(amount);
    setState(() => _loading = false);
    if (!mounted) return;

    if (result.isSuccess) {
      await _notif.showTopUpSuccess(amount);
      _showSuccess(amount);
    } else {
      _snack(result.error ?? 'Top-up failed. Please try again.');
    }
  }

  Future<bool> _showStkDialog(double amount) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.phone_android, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('M-Pesa Request',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Confirm top-up of KSh ${amount.toStringAsFixed(0)} to your Transit Pay wallet.',
                style: const TextStyle(fontSize: 14, color: AppColors.gray700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      color: AppColors.secondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Simulated for MVP — no real money moves.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.secondary)),
                  ),
                ]),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.gray500))),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10)),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccess(double amount) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.secondaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle,
                color: AppColors.secondary, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Top-Up Successful!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
          const SizedBox(height: 8),
          Text(
            'KSh ${amount.toStringAsFixed(0)} added to your wallet.',
            style: const TextStyle(color: AppColors.gray500, fontSize: 15),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Back to Home'),
          ),
        ]),
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top Up Wallet')),
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // M-Pesa header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.phone_android,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('M-Pesa',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.dark)),
                Text('Lipa Na M-Pesa',
                    style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
          const SizedBox(height: 28),

          const Text('Select Amount',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.dark)),
          const SizedBox(height: 12),
          AmountSelector(
            selected: _showCustom ? null : _selected,
            onSelect: (a) => setState(() {
              _selected = a;
              _showCustom = false;
              _customCtrl.clear();
            }),
          ),
          const SizedBox(height: 16),

          // Custom amount toggle
          GestureDetector(
            onTap: () => setState(() {
              _showCustom = !_showCustom;
              _selected = null;
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _showCustom ? AppColors.primaryLight : AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _showCustom
                        ? AppColors.primary
                        : Colors.transparent),
              ),
              child: Row(children: [
                Icon(Icons.edit_outlined,
                    color: _showCustom ? AppColors.primary : AppColors.gray500,
                    size: 18),
                const SizedBox(width: 8),
                Text('Enter custom amount',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _showCustom
                            ? AppColors.primary
                            : AppColors.gray700)),
              ]),
            ),
          ),

          if (_showCustom) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Amount (KSh)',
                  prefixText: 'KSh  ',
                  hintText: 'e.g. 350'),
            ),
          ],

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.gray500, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'No top-up fees. Amount reflects instantly in your wallet.',
                    style: TextStyle(color: AppColors.gray500, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _loading ? null : _processTopUp,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Top Up via M-Pesa'),
          ),
        ]),
      ),
    );
  }
}
