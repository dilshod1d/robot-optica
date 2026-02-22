import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AiAnalyzeLoader extends StatelessWidget {
  final double size;
  final bool repeat;

  const AiAnalyzeLoader({
    super.key,
    this.size = 180,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/eye-analysis.json',
        width: size,
        height: size,
        repeat: repeat,
      ),
    );
  }
}
