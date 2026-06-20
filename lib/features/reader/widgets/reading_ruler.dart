import 'package:flutter/material.dart';

import '../../../app/theme/reading_theme.dart';
import '../../../domain/models/reading_prefs.dart';

/// A reading-focus band painted on top of the reading surface.
///
/// A horizontal focus band rests at [center] (a fraction of the viewport
/// height) and the text scrolls underneath it (the band ignores pointer
/// events), so it behaves like a physical reading ruler / typoscope held still
/// over the page while you read — it auto-follows your reading rather than
/// needing to be dragged.
///
/// Styles follow the CHI-2023 "Digital Reading Rulers" set (see
/// docs/RESEARCH.md §1): [ReadingRulerStyle.bar] (tinted band),
/// [ReadingRulerStyle.underline], [ReadingRulerStyle.shade] (light dimming
/// above/below) and [ReadingRulerStyle.spotlight] (stronger dimming). The
/// [ReadingRulerStyle.off] and [ReadingRulerStyle.highlight] modes paint no
/// band, so this overlay renders nothing for them (the highlight is in-text).
class ReadingRulerOverlay extends StatelessWidget {
  const ReadingRulerOverlay({
    super.key,
    required this.style,
    required this.palette,
    required this.bandHeight,
    required this.center,
  });

  final ReadingRulerStyle style;
  final ReadingPalette palette;

  /// Height of the focus band in logical pixels.
  final double bandHeight;

  /// Vertical centre of the band as a fraction of the viewport height (0–1).
  final double center;

  @override
  Widget build(BuildContext context) {
    if (!style.isBand) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (h <= 0) return const SizedBox.shrink();
        final band = bandHeight.clamp(16.0, h);
        final top = (center * h - band / 2).clamp(0.0, h - band);
        final accent = palette.accent;

        final layers = <Widget>[];
        switch (style) {
          case ReadingRulerStyle.off:
          case ReadingRulerStyle.highlight:
            break;
          case ReadingRulerStyle.spotlight:
          case ReadingRulerStyle.shade:
            final dim = style == ReadingRulerStyle.spotlight ? 0.5 : 0.22;
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

        return IgnorePointer(child: Stack(children: layers));
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
