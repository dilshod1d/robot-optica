import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/care_plan_model.dart';
import '../../services/prescription_service.dart';


class CustomerPrescriptionsWidget extends StatelessWidget {
  final String customerId;
  final String opticaId;

  const CustomerPrescriptionsWidget({
    super.key,
    required this.customerId,
    required this.opticaId,
  });

  @override
  Widget build(BuildContext context) {
    final service = PrescriptionService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Prescriptions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<List<CarePlanModel>>(
            stream: service.streamCarePlansByCustomer(
              opticaId: opticaId,
              customerId: customerId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: AppLoader());
              }

              if (snapshot.hasError) {
                print('Error loading prescriptions: ${snapshot.error}');
                return const Center(child: Text("Failed to load prescriptions"));
              }

              final plans = snapshot.data ?? [];

              if (plans.isEmpty) {
                return const Center(child: EmptyState());
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: plans.map((plan) {
                  return PrescriptionCard(
                    date: _formatDate(plan.createdAt),
                    generalAdvice: plan.generalAdvice,
                    items: plan.items.map((item) {
                      return PrescriptionItemUI(
                        title: item.title,
                        instruction: item.instruction,
                        dosage: item.dosage.toString(),
                        duration: item.duration.toString(),
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

class PrescriptionCard extends StatelessWidget {
  final String date;
  final String? generalAdvice;
  final List<PrescriptionItemUI> items;

  const PrescriptionCard({
    super.key,
    required this.date,
    this.generalAdvice,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.medical_services, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                "Retsept",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                date,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...items.map((e) => e).toList(),

          if (generalAdvice != null) ...[
            const Divider(height: 24),
            Text(
              "Umumiy tavsiya: $generalAdvice",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}


class PrescriptionItemUI extends StatelessWidget {
  final String title;
  final String instruction;
  final String dosage;
  final String duration;

  const PrescriptionItemUI({
    super.key,
    required this.title,
    required this.instruction,
    required this.dosage,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (instruction.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              instruction,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 6),

          _row("Mahal", dosage),
          _row("Davomiyligi", duration),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
