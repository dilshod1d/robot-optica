import 'package:flutter/material.dart';
import '../../models/billing_model.dart';
import '../../services/billing_service.dart';
import '../../widgets/billing/billing_status_chip.dart';
import '../../widgets/billing/pay_bottom_sheet.dart';
import '../../widgets/billing/payment_tile.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/responsive_frame.dart';

class BillingDetailScreen extends StatelessWidget {
  final String opticaId;
  final BillingModel billing;
  final BillingFirebaseService service;

  const BillingDetailScreen({
    super.key,
    required this.opticaId,
    required this.billing,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hisob-kitob tafsilotlari")),
      body: ResponsiveFrame(
        maxWidth: 900,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        applyPaddingWhenNarrow: true,
        child: Column(
          children: [
            _header(context),
            const Divider(),
            Expanded(child: _payments()),
          ],
        ),
      ),
      floatingActionButton: billing.remaining > 0
          ? FloatingActionButton.extended(
        onPressed: () => _pay(context),
        label: const Text("To'lash"),
        icon: const Icon(Icons.payment),
      )
          : null,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BillingStatusChip(status: billing.liveStatus),
          const SizedBox(height: 12),
          Text(
            "Jami: ${billing.amountDue.toStringAsFixed(0)} so'm",
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            "To'langan: ${billing.amountPaid.toStringAsFixed(0)} so'm",
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            "Qolgan: ${billing.remaining.toStringAsFixed(0)} so'm",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "To'lanishi kerak: ${billing.dueDate.toDate().toLocal().toString().split(' ')[0]}",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _payments() {
    return StreamBuilder(
      stream: service.watchPayments(
        opticaId: opticaId,
        billingId: billing.id,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppLoader();
        }

        final payments = snapshot.data!;

        if (payments.isEmpty) {
          return const Center(child: Text("No payments yet"));
        }

        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (_, i) => PaymentTile(payment: payments[i]),
        );
      },
    );
  }

  void _pay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PayBottomSheet(
        maxAmount: billing.remaining,
        onConfirm: (amount, note) async {
          await service.applyPayment(
            opticaId: opticaId,
            billing: billing,
            amount: amount,
            note: note,
          );
        },
      ),
    );
  }

}
