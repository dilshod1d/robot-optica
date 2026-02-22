import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/customer_model.dart';
import '../../models/eye_scan_result.dart';
import '../../services/eye_scan_service.dart';
import 'eye_scan_card.dart';
import 'improvement_summary.dart';

class PatientEyeAnalysesWidget extends StatelessWidget {
  final CustomerModel customer;

  const PatientEyeAnalysesWidget({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final service = EyeScanService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Analizlar", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<List<EyeScanResult>>(
            stream: service.streamByCustomer(
              opticaId: customer.opticaId,
              customerId: customer.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: AppLoader());
              }

              if (snapshot.hasError) {
                return const Center(child: Text("Failed to load analyses"));
              }

              final scans = snapshot.data ?? [];

              if (scans.isEmpty) {
                return const Center(child: EmptyState());
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  ImprovementSummary(scans: scans),
                  const SizedBox(height: 12),
                  ...scans.map((scan) => EyeScanCard(scan: scan)).toList(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

