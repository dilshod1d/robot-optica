import 'package:flutter/material.dart';
import '../../models/payment_model.dart';


class PaymentTile extends StatelessWidget {
  final PaymentModel payment;

  const PaymentTile({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("${payment.amount.toStringAsFixed(0)} so'm"),
      subtitle: payment.note != null ? Text(payment.note!) : null,
      trailing: Text(
        payment.paidAt.toDate().toLocal().toString().split(' ')[0],
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
