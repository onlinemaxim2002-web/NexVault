import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/backend.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The user's own payments (the database only returns their orders).
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<PaymentOrder>? orders;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Backend.paymentHistory();
      if (!mounted) return;
      setState(() {
        orders = list;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  static String statusLabel(String s) => switch (s) {
    'approved' => 'Successful',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    'revoked' => 'Reversed',
    _ => 'Pending',
  };

  static Color statusColor(String s) => switch (s) {
    'approved' => AppColors.success,
    'failed' => AppColors.danger,
    'cancelled' || 'revoked' => AppColors.muted,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.barGradient),
          child: SizedBox.expand(),
        ),
        title: const Text('Payment history'),
      ),
      body: error != null && orders == null
          ? ErrorRetry(message: error!, onRetry: _load)
          : orders == null
          ? const Center(child: CircularProgressIndicator())
          : orders!.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long,
              message: 'No payments yet.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: orders!.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = orders![i];
                  return ListTile(
                    title: Text('${o.planName ?? 'Plan'} · ${o.amountLabel}'),
                    subtitle: Text(
                      'Order ${o.reference}\n${fmt.format(o.createdAt.toLocal())}'
                      '${o.txnId != null ? '\nUTR ${o.txnId}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      statusLabel(o.status),
                      style: TextStyle(
                        color: statusColor(o.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
