import 'package:flutter/material.dart';

/// Material 3 window-size classes used to pick adaptive layouts across phones,
/// tablets, and larger screens.
///
/// Thresholds follow the Material 3 canonical breakpoints: compact < 600 dp,
/// medium 600–1023 dp, expanded >= 1024 dp.
enum WindowSize {
  /// Phones in portrait and small windows: width < 600 dp.
  compact,

  /// Large phones in landscape and small tablets: 600–1023 dp.
  medium,

  /// Tablets and desktops: width >= 1024 dp.
  expanded;

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;
  bool get isExpanded => this == WindowSize.expanded;

  /// True when there is enough width to prefer a side navigation rail and a
  /// two-pane layout over a bottom navigation bar and single column.
  bool get useNavigationRail => this != WindowSize.compact;

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 1024) return WindowSize.medium;
    return WindowSize.expanded;
  }

  /// Resolve the current window size from the ambient [MediaQuery] width.
  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}

/// Comfortable maximum width for reading-oriented content columns. Past this,
/// content is centered with side margins instead of stretching edge to edge on
/// tablets and desktops (long line lengths hurt readability, dyslexic or not).
const double kMaxContentWidth = 720;

/// Centers [child] and caps its width at [maxWidth] so long-form content stays
/// readable on wide screens. On narrow screens the cap is never reached, so it
/// behaves as a simple top-aligned passthrough.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
