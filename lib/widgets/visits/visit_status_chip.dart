import 'package:flutter/material.dart';
import '../../models/visit_model.dart';
import '../../optica_theme.dart';


class VisitStatusChip extends StatelessWidget {
  final VisitStatus status;

  const VisitStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;

    switch (status) {
      case VisitStatus.pending:
        color = OpticaColors.pending;
        label = 'Kutilmoqda';
        break;
      case VisitStatus.visited:
        color = OpticaColors.visited;
        label = 'Tashrif tugallangan';
        break;
      case VisitStatus.lateVisited:
        color = OpticaColors.late;
        label = 'Kech kelgan';
        break;
      case VisitStatus.notVisited:
        color = OpticaColors.missed;
        label = 'O\'tib ketgan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
