import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/customer_model.dart';
import '../../models/eye_scan_result.dart';
import '../../services/eye_scan_service.dart';
import 'add_analysis_sheet.dart';
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

    Future<bool> confirmDelete(EyeScanResult scan) async {
      if (scan.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Analiz ID topilmadi")),
        );
        return false;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Analizni o'chirish"),
          content: const Text("Ushbu analizni o'chirishni xohlaysizmi?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Bekor qilish"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("O'chirish"),
            ),
          ],
        ),
      );

      if (confirmed != true) return false;

      try {
        await service.deleteAnalysis(
          opticaId: customer.opticaId,
          analysisId: scan.id!,
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("O'chirib bo'lmadi: $e")),
        );
        return false;
      }
    }

    void openEdit(EyeScanResult scan) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => AddAnalysisSheet(
          customerId: customer.id,
          opticaId: customer.opticaId,
          existingScan: scan,
        ),
      );
    }

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
                  ...scans.map((scan) {
                    return Dismissible(
                      key: ValueKey(scan.id ?? scan.hashCode),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => confirmDelete(scan),
                      child: EyeScanCard(
                        scan: scan,
                        onEdit: () => openEdit(scan),
                        onDelete: () => confirmDelete(scan),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
