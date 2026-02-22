// // widgets/customer_card.dart
// import 'package:flutter/material.dart';
// import '../models/customer_model.dart';
//
// class CustomerCard extends StatelessWidget {
//   final CustomerModel customer;
//   final VoidCallback onTap;
//
//   const CustomerCard({
//     super.key,
//     required this.customer,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       elevation: 3,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(12),
//         title: Text(
//           '${customer.firstName} ${customer.lastName ?? ''}'.trim(),
//           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         subtitle: Text(
//           customer.phone,
//           style: const TextStyle(color: Colors.grey),
//         ),
//         trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
//         onTap: onTap,
//       ),
//     );
//   }
// }
