import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';

class PayBottomSheet extends StatefulWidget {
  final double maxAmount;
  final Future<void> Function(double amount, String note) onConfirm;

  const PayBottomSheet({
    super.key,
    required this.maxAmount,
    required this.onConfirm,
  });

  @override
  State<PayBottomSheet> createState() => _PayBottomSheetState();
}

class _PayBottomSheetState extends State<PayBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  bool loading = false;
  bool isPartial = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          Text("Qolgan: ${widget.maxAmount.toStringAsFixed(2)} UZS"),

          const SizedBox(height: 12),

          /// Amount
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "To'lanadigan summa",
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final v = double.tryParse(val);
              if (v != null) {
                setState(() {
                  isPartial = v != widget.maxAmount;
                });
              }
            },
          ),

          const SizedBox(height: 12),

          /// Note
          TextField(
            controller: _noteController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: "Izoh (ixtiyoriy)",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                final amount =
                double.tryParse(_amountController.text);

                if (amount == null || amount <= 0) return;

                setState(() => loading = true);

                await widget.onConfirm(
                  amount,
                  _noteController.text.trim(),
                );

                if (mounted) Navigator.pop(context);
              },
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
