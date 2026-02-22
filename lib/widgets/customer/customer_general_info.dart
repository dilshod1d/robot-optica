import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import '../../models/customer_model.dart';
import '../../services/customer_service.dart';
import 'edit_customer_info_sheet.dart';
import 'info_row.dart';

class CustomerGeneralInfo extends StatefulWidget {
  final CustomerModel customer;
  final String opticaId;

  const CustomerGeneralInfo({
    super.key,
    required this.customer,
    required this.opticaId,
  });

  @override
  State<CustomerGeneralInfo> createState() => _CustomerGeneralInfoState();
}

class _CustomerGeneralInfoState extends State<CustomerGeneralInfo> {
  final _service = CustomerService();

  late bool _visitsSms;
  late bool _debtsSms;

  bool _loadingVisits = false;
  bool _loadingDebts = false;

  @override
  void initState() {
    super.initState();
    _visitsSms = widget.customer.visitsSmsEnabled;
    _debtsSms = widget.customer.debtsSmsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: "General info",
      customer: widget.customer,
      child: Column(
        children: [
          InfoRow(
            label: "Ism",
            value: widget.customer.firstName,
          ),
          InfoRow(
            label: "Familya",
            value: widget.customer.lastName ?? "-",
          ),
          InfoRow(
            label: "Telefon",
            value: widget.customer.phone,
          ),
          InfoRow(
            label: "Qo'shilgan sana",
            value: _formatDate(widget.customer.createdAt),
          ),

          const SizedBox(height: 16),
          const Divider(),

          _SmsSwitchRow(
            label: "Tashriflar uchun sms",
            value: _visitsSms,
            loading: _loadingVisits,
            onChanged: _toggleVisitsSms,
          ),

          _SmsSwitchRow(
            label: "Qarzlar uchun sms",
            value: _debtsSms,
            loading: _loadingDebts,
            onChanged: _toggleDebtsSms,
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return "-";
    final date = ts.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _toggleVisitsSms(bool value) async {
    setState(() {
      _loadingVisits = true;
      _visitsSms = value;
    });

    try {
      await _service.setVisitsSmsEnabled(
        opticaId: widget.opticaId,
        customerId: widget.customer.id,
        enabled: value,
      );
    } catch (e) {
      setState(() {
        _visitsSms = !value;
      });
    }

    setState(() => _loadingVisits = false);
  }

  Future<void> _toggleDebtsSms(bool value) async {
    setState(() {
      _loadingDebts = true;
      _debtsSms = value;
    });

    try {
      await _service.setDebtsSmsEnabled(
        opticaId: widget.opticaId,
        customerId: widget.customer.id,
        enabled: value,
      );
    } catch (e) {
      print('error toggle sms $e');
      setState(() {
        _debtsSms = !value;
      });
    }

    setState(() => _loadingDebts = false);
  }
}


class _SmsSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool loading;
  final ValueChanged<bool> onChanged;

  const _SmsSwitchRow({
    required this.label,
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: AppLoader(
                size: 22,
                fill: false,
              ),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}



class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final CustomerModel customer;

  const _Section({
    required this.title,
    required this.child,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => EditCustomerInfoSheet(
                      isEdit: true,
                      customer: customer,
                    ),
                  );
                },
                child: const Text("Edit", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

