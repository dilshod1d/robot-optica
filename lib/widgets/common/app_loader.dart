import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatelessWidget {
  final double size;
  final bool repeat;
  final bool fill;
  final Alignment alignment;

  const AppLoader({
    super.key,
    this.size = 180,
    this.repeat = true,
    this.fill = true,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Lottie.asset(
      'assets/eyeface.json',
      width: size,
      height: size,
      repeat: repeat,
      fit: BoxFit.contain,
    );

    if (!fill) {
      return Align(
        alignment: alignment,
        child: animation,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final mediaSize = MediaQuery.of(context).size;

        return SizedBox(
          height: hasBoundedHeight ? constraints.maxHeight : mediaSize.height,
          width: hasBoundedWidth ? constraints.maxWidth : mediaSize.width,
          child: Align(
            alignment: alignment,
            child: animation,
          ),
        );
      },
    );
  }
}
