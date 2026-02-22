import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/visit_model.dart';
import '../../optica_theme.dart';
import 'visit_status_chip.dart';

class VisitCard extends StatelessWidget {
  final VisitModel visit;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool showCustomerName;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.onMore,
    this.showCustomerName = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
         padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OpticaColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _LeftStripe(status: visit.status),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCustomerName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        visit.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OpticaColors.textPrimary,
                        ),
                      ),
                    ),
                  Text(
                    visit.reason,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: OpticaColors.textPrimary,
                    ),
                  ),

                  if (visit.note != null && visit.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        visit.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: OpticaColors.textSecondary,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: OpticaColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm')
                            .format(visit.visitDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: OpticaColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      VisitStatusChip(status: visit.status),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            GestureDetector(
              onTap: onMore,
              child: const Icon(
                Icons.more_vert,
                color: OpticaColors.textSecondary,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LeftStripe extends StatelessWidget {
  final VisitStatus status;

  const _LeftStripe({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case VisitStatus.pending:
        color = OpticaColors.pending;
        break;
      case VisitStatus.visited:
        color = OpticaColors.visited;
        break;
      case VisitStatus.lateVisited:
        color = OpticaColors.late;
        break;
      case VisitStatus.notVisited:
        color = OpticaColors.missed;
        break;
    }

    return Container(
      width: 4,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
