import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/billing/billing_item_card.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/billing_model.dart';
import '../../services/billing_service.dart';
import '../../widgets/billing/reschedule_debt_sheet.dart';


class CustomerBillingWidget extends StatelessWidget {
  final String opticaId;
  final String customerId;

  const CustomerBillingWidget({
    super.key,
    required this.opticaId,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    final service = BillingFirebaseService();

    return StreamBuilder<List<BillingModel>>(
      stream: service.watchByCustomer(
        opticaId: opticaId,
        customerId: customerId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        print(snapshot.data);

        if (snapshot.hasError) {
          return const Text("Nimadir noto'g'ri ketdi");
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyState();
        }

        final bills = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Hisob-kitob tarixi",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
          
              ...bills.map((bill) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillingItemCard(
                    bill: bill,
                    onPay: () => _showPayModal(context, bill, opticaId),
                    onEdit: bill.remaining > 0
                        ? () => _reschedule(context, service, opticaId, bill)
                        : null,
                  ),
                  // child: _billItem(context, bill, opticaId),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }



  void _showPayModal(
      BuildContext context,
      BillingModel billing,
      String opticaId,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PayModal(
        billing: billing,
        opticaId: opticaId,
      ),
    );
  }

  Future<void> _reschedule(
    BuildContext context,
    BillingFirebaseService service,
    String opticaId,
    BillingModel bill,
  ) async {
    final result = await RescheduleDebtSheet.show(
      context: context,
      initialDate: bill.dueDate.toDate(),
    );
    if (result == null) return;
    await service.rescheduleDebt(
      opticaId: opticaId,
      billing: bill,
      newDate: result.date,
      resetSms: result.resetSms,
    );
  }

}

class _PayModal extends StatefulWidget {
  final BillingModel billing;
  final String opticaId;

  const _PayModal({
    required this.billing,
    required this.opticaId,
  });

  @override
  State<_PayModal> createState() => _PayModalState();
}

class _PayModalState extends State<_PayModal> {
  late TextEditingController _controller;
  bool isPartial = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.billing.remaining.toStringAsFixed(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = BillingFirebaseService();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hisobni to'lash",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          Text(
              "Qolgan: ${widget.billing.remaining.toStringAsFixed(0)} UZS"),

          const SizedBox(height: 12),

          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "To'lanadigan summa",
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final v = double.tryParse(val);
              if (v != null) {
                setState(() {
                  isPartial = v != widget.billing.remaining;
                });
              }
            },
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                final amount =
                double.tryParse(_controller.text);

                if (amount == null || amount <= 0) return;

                setState(() => loading = true);

                await service.applyPayment(
                  opticaId: widget.opticaId,
                  billing: widget.billing,
                  amount: amount,
                );

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green),
              child: loading
                  ? const AppLoader(
                size: 20,
                fill: false,
              )
                  : const Text("To'lovni tasdiqlash"),
            ),
          ),
        ],
      ),
    );
  }
}

