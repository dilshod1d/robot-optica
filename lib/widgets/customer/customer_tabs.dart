import 'package:flutter/material.dart';

class CustomerTabs extends StatelessWidget {
  final int activeIndex;
  final Function(int) onChanged;
  final bool isVertical;
  final double? width;

  const CustomerTabs({
    super.key,
    required this.activeIndex,
    required this.onChanged,
    this.isVertical = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _TabItem("Umumiy", Icons.person_outline),
      _TabItem("Tashrif", Icons.event_note_outlined),
      _TabItem("Retsept", Icons.description_outlined),
      _TabItem("Analiz", Icons.remove_red_eye_outlined),
      _TabItem("To'lov", Icons.receipt_long_outlined),
      _TabItem("Xabarlar", Icons.sms_outlined),
    ];

    if (isVertical) {
      return SizedBox(
        width: width ?? 220,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final isActive = index == activeIndex;
            return InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? Colors.blue : Colors.grey.shade300,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      tabs[index].icon,
                      size: 18,
                      color: isActive ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tabs[index].label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;

          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive ? Colors.blue : Colors.grey.shade300,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    tabs[index].icon,
                    size: 20,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tabs[index].label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;

  _TabItem(this.label, this.icon);
}
