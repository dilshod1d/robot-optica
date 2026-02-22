import 'package:flutter/material.dart';
import '../../models/care_item.dart';
import '../../services/prescription_service.dart';
import '../../optica_theme.dart';

class CareItemCard extends StatelessWidget {
  final CareItem item;
  final String opticaId;

  const CareItemCard({
    super.key,
    required this.item,
    required this.opticaId,
  });

  @override
  Widget build(BuildContext context) {
    final service = PrescriptionService();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OpticaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OpticaColors.primary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: OpticaColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _icon(),
          const SizedBox(width: 14),

          // -------- CONTENT --------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OpticaColors.textPrimary,
                  ),
                ),

                if (item.instruction.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OpticaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 8),

                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _infoChip(
                      icon: Icons.medication_outlined,
                      label: "${item.dosage}",
                    ),
                    if (item.duration != null)
                      _infoChip(
                        icon: Icons.timelapse,
                        label: item.duration!.toString(),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // -------- DELETE --------
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: OpticaColors.missed,
            ),
            tooltip: "O‘chirish",
            onPressed: () async {
              await service.deleteCareItem(opticaId, item.id);
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // UI PARTS
  // --------------------------------------------------

  Widget _icon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: OpticaColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.medical_services_outlined,
        color: OpticaColors.primary,
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OpticaColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OpticaColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OpticaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
