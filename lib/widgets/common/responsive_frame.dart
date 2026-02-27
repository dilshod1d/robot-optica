import 'package:flutter/material.dart';

class ResponsiveFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool applyPaddingWhenNarrow;

  const ResponsiveFrame({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
    this.applyPaddingWhenNarrow = false,
  });

  static bool isDesktopWidth(double width) => width >= 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final isDesktop = isDesktopWidth(width);
        final effectiveMaxWidth = isDesktop ? maxWidth : double.infinity;
        final effectivePadding = padding ??
            EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 0);

        final appliedPadding = isDesktop
            ? effectivePadding
            : (applyPaddingWhenNarrow ? effectivePadding : EdgeInsets.zero);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
            child: Padding(
              padding: appliedPadding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int minCrossAxisCount;
  final int maxCrossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 4,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1.4,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        int count = (width / minItemWidth).floor();
        if (count < minCrossAxisCount) count = minCrossAxisCount;
        if (count > maxCrossAxisCount) count = maxCrossAxisCount;
        if (count < 1) count = 1;

        return GridView.count(
          padding: padding,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

class SheetFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const SheetFrame({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final insets = media.viewInsets;
    final viewPadding = media.viewPadding;
    final defaultPadding = EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: insets.bottom + viewPadding.bottom + 20,
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: ResponsiveFrame(
          maxWidth: maxWidth,
          applyPaddingWhenNarrow: true,
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}
