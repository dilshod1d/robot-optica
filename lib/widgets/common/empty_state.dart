import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../optica_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final double animationSize;

  const EmptyState({
    super.key,
    this.title = "Ma'lumot yo'q",
    this.subtitle = "Bu yerda hali ko'rsatadigan hech narsa yo'q.",
    this.animationSize = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/empty.json',
            width: animationSize,
            height: animationSize,
            repeat: true,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OpticaColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: OpticaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
