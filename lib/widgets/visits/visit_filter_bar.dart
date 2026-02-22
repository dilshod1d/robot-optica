import 'package:flutter/material.dart';
import '../../optica_theme.dart';

class VisitFilterBar extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final Function(String) onChanged;

  /// UI labels for filters
  final Map<String, String> labels;

  const VisitFilterBar({
    super.key,
    required this.selected,
    required this.filters,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final filter = filters[i];
          final isActive = filter == selected;
          final label = labels[filter] ?? filter;

          return GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? OpticaColors.primary
                    : OpticaColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : OpticaColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
