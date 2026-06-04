/// Cleans common extraction / OCR artefacts ("relic" characters): typographic
/// ligatures, soft hyphens, zero-width and control/replacement characters, and
/// runs of whitespace — so the reflowed text reads cleanly.
class TextCleanup {
  TextCleanup._();

  static const Map<String, String> _ligatures = {
    'ﬀ': 'ff',
    'ﬁ': 'fi',
    'ﬂ': 'fl',
    'ﬃ': 'ffi',
    'ﬄ': 'ffl',
    'ﬅ': 'st',
    'ﬆ': 'st',
  };

  // Control chars (incl. stray \n\t inside a block) -> space; format chars
  // (soft hyphen, zero-width, BOM) -> removed.
  static final RegExp _control = RegExp(r'\p{Cc}', unicode: true);
  static final RegExp _format = RegExp(r'\p{Cf}', unicode: true);
  static final RegExp _spaces = RegExp(r'[ \t]{2,}');
  // Unicode space separators (NBSP, thin/figure spaces, …) → normal space.
  static final RegExp _spaceSep = RegExp(r'\p{Zs}', unicode: true);

  static String clean(String s) {
    var out = _foldCompatibility(s);
    _ligatures.forEach((k, v) => out = out.replaceAll(k, v));
    out = out
        .replaceAll('�', ' ') // replacement character
        .replaceAll(_format, '') // zero-width, soft hyphen, BOM
        .replaceAll(_control, ' ') // control chars (incl. stray \n\t)
        .replaceAll(_spaceSep, ' '); // NBSP and friends
    return out.replaceAll(_spaces, ' ');
  }

  /// NFKC-style compatibility folding for the artefacts that actually show up
  /// in OCR / PDF text: full-width ASCII forms and the ideographic space.
  static String _foldCompatibility(String s) {
    if (!s.runes.any((r) => r == 0x3000 || (r >= 0xFF01 && r <= 0xFF5E))) {
      return s; // fast path: nothing to fold
    }
    final buf = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF01 && r <= 0xFF5E) {
        buf.writeCharCode(r - 0xFEE0); // full-width → ASCII
      } else if (r == 0x3000) {
        buf.write(' '); // ideographic space → space
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }
}
