import 'package:flutter/material.dart';

import '../../optica_theme.dart';


class VisitActionSheet {
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onVisited,
    required VoidCallback onLateVisited,
    required VoidCallback onNotVisited,
    required VoidCallback onReschedule,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionItem("Tugallangan deb belgilash", Icons.check_circle, OpticaColors.visited, onVisited),
              // _ActionItem("Mark Late Visited", Icons.access_time, OpticaColors.late, onLateVisited),
              _ActionItem("Tashrif sanasini ko‘chirish", Icons.event, OpticaColors.primary, onReschedule),
              _ActionItem("O'tkazib yuborilgan deb belgilash", Icons.cancel, OpticaColors.missed, onNotVisited),
              const Divider(),
              _ActionItem("Tashrifni o'chirib yuborish", Icons.delete, Colors.red, onDelete),
            ],
          ),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
