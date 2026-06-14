import 'package:flutter/material.dart';

import '../../../app/theme/reading_theme.dart';
import '../../../domain/models/reading_prefs.dart';

/// A reading-ruler / line-focus overlay painted on top of the reading surface.
///
/// A horizontal focus band sits at [center] (a fraction of the viewport height)
/// and can be dragged up/down by the grip on its right edge. Text scrolls
/// underneath it (the band itself ignores pointer events), so it behaves like a
/// physical reading ruler / typoscope held over the page.
///
/// Styles follow the CHI-2023 "Digital Reading Rulers" set (see
/// docs/RESEARCH.md §1): [ReadingRulerStyle.bar] (tinted band),
/// [ReadingRulerStyle.underline], [ReadingRulerStyle.shade] (light dimming
/// above/below) and [ReadingRulerStyle.spotlight] (stronger dimming).
class ReadingRulerOverlay extends StatefulWidget {
  const ReadingRulerOverlay({
    super.key,
    required this.style,
    required this.palette,
    required this.bandHeight,
    required this.center,
    required this.onCenterChanged,
  });

  final ReadingRulerStyle style;
  final ReadingPalette palette;

  /// Height of the focus band in logical pixels.
  final double bandHeight;

  /// Vertical centre of the band as a fraction of the viewport height (0–1).
  final double center;

  /// Called when the user finishes dragging the band (commit the new centre).
  final ValueChanged<double> onCenterChanged;

  @override
  State<ReadingRulerOverlay> createState() => _ReadingRulerOverlayState();
}

class _ReadingRulerOverlayState extends State<ReadingRulerOverlay> {
  late double _center = widget.center;

  @override
  void didUpdateWidget(covariant ReadingRulerOverlay old) {
    super.didUpdateWidget(old);
    // Adopt external changes (e.g. a settings reset) when not mid-drag.
    if (old.center != widget.center && widget.center != _center) {
      _center = widget.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == ReadingRulerStyle.off) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (h <= 0) return const SizedBox.shrink();
        final band = widget.bandHeight.clamp(16.0, h);
        final top = (_center * h - band / 2).clamp(0.0, h - band);
        final accent = widget.palette.accent;

        final layers = <Widget>[];
        switch (widget.style) {
          case ReadingRulerStyle.off:
            break;
          case ReadingRulerStyle.spotlight:
          case ReadingRulerStyle.shade:
            final dim = widget.style == ReadingRulerStyle.spotlight ? 0.5 : 0.22;
            layers.add(_panel(top: 0, height: top, color: Colors.black.withValues(alpha: dim)));
            layers.add(_panel(top: top + band, bottom: 0, color: Colors.black.withValues(alpha: dim)));
            layers.add(_panel(top: top, height: 2, color: accent.withValues(alpha: 0.55)));
            layers.add(_panel(top: top + band - 2, height: 2, color: accent.withValues(alpha: 0.55)));
          case ReadingRulerStyle.bar:
            layers.add(_panel(top: top, height: band, color: accent.withValues(alpha: 0.16)));
          case ReadingRulerStyle.underline:
            layers.add(_panel(top: top, height: band, color: accent.withValues(alpha: 0.06)));
            layers.add(_panel(top: top + band - 3, height: 3, color: accent));
        }

        const handleH = 56.0;
        final handleTop = (top + band / 2 - handleH / 2).clamp(0.0, h - handleH);

        return Stack(
          children: [
            IgnorePointer(child: Stack(children: layers)),
            Positioned(
              right: 0,
              top: handleTop,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => setState(() {
                  _center = ((_center * h) + d.delta.dy).clamp(0.0, h) / h;
                }),
                onVerticalDragEnd: (_) => widget.onCenterChanged(_center),
                child: Semantics(
                  label: 'Drag to move the reading ruler',
                  button: true,
                  // 48-wide transparent hit area (accessible touch target);
                  // the visible grip stays a 26-wide pill on the right edge.
                  child: SizedBox(
                    width: 48,
                    height: handleH,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 26,
                        height: handleH,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius:
                              const BorderRadius.horizontal(left: Radius.circular(13)),
                        ),
                        child: Icon(Icons.drag_indicator,
                            size: 18, color: widget.palette.background),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _panel({required double top, double? height, double? bottom, required Color color}) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: height,
      bottom: bottom,
      child: ColoredBox(color: color),
    );
  }
}
