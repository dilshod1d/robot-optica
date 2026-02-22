// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import '../models/customer_model.dart';
//
// class CustomerForm extends StatefulWidget {
//   final CustomerModel? existing;
//   final Future<void> Function(CustomerModel) onSave;
//
//   const CustomerForm({
//     super.key,
//     this.existing,
//     required this.onSave,
//   });
//
//   @override
//   State<CustomerForm> createState() => _CustomerFormState();
// }
//
// class _CustomerFormState extends State<CustomerForm> {
//   final _formKey = GlobalKey<FormState>();
//   final _phoneFocus = FocusNode();
//   final _lastNameFocus = FocusNode();
//
//   late String firstName;
//   String? lastName;
//   late String phone;
//   bool _isSubmitting = false;
//
//   @override
//   void initState() {
//     super.initState();
//     firstName = widget.existing?.firstName ?? '';
//     lastName = widget.existing?.lastName ?? '';
//     phone = widget.existing?.phone ?? '';
//   }
//
//   @override
//   void dispose() {
//     _phoneFocus.dispose();
//     _lastNameFocus.dispose();
//     super.dispose();
//   }
//
//   Future<void> _submit() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isSubmitting = true);
//
//       final model = CustomerModel(
//         id: widget.existing?.id ?? UniqueKey().toString(),
//         firstName: firstName.trim(),
//         lastName: lastName?.trim().isEmpty == true ? null : lastName,
//         phone: phone.trim(),
//         createdAt: Timestamp.fromDate(DateTime.now()), opticaId: '',
//       );
//
//       await widget.onSave(model);
//
//       if (mounted) {
//         setState(() => _isSubmitting = false);
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           children: [
//             TextFormField(
//               initialValue: firstName,
//               decoration: const InputDecoration(
//                 labelText: 'Ism',
//                 prefixIcon: Icon(Icons.person_outline),
//               ),
//               textInputAction: TextInputAction.next,
//               onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocus),
//               onChanged: (val) => firstName = val,
//               validator: (val) => val!.trim().isEmpty ? 'Ism talab qilinadi' : null,
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               initialValue: lastName ?? '',
//               focusNode: _lastNameFocus,
//               decoration: const InputDecoration(
//                 labelText: 'Familiya (ixtiyoriy)',
//                 prefixIcon: Icon(Icons.person),
//               ),
//               textInputAction: TextInputAction.next,
//               onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
//               onChanged: (val) => lastName = val.trim().isEmpty ? null : val,
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               initialValue: phone,
//               focusNode: _phoneFocus,
//               decoration: const InputDecoration(
//                 labelText: 'Telefon raqami',
//                 prefixIcon: Icon(Icons.phone),
//               ),
//               keyboardType: TextInputType.phone,
//               onChanged: (val) => phone = val,
//               validator: (val) => val!.trim().isEmpty ? 'Telefon raqami kerak' : null,
//             ),
//             const SizedBox(height: 32),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: _isSubmitting
//                     ? const SizedBox(
//                   width: 18,
//                   height: 18,
//                   child: CircularProgressIndicator(
//                     color: Colors.white,
//                     strokeWidth: 2,
//                   ),
//                 )
//                     : const Icon(Icons.save),
//                 label: Text(_isSubmitting ? 'Saqlanmoqda...' : 'Saqlash'),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 ),
//                 onPressed: _isSubmitting ? null : _submit,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
