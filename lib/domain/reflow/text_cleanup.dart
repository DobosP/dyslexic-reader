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

  static String clean(String s) {
    var out = s;
    _ligatures.forEach((k, v) => out = out.replaceAll(k, v));
    out = out
        .replaceAll('�', ' ') // replacement character
        .replaceAll(_format, '')
        .replaceAll(_control, ' ');
    return out.replaceAll(_spaces, ' ');
  }
}
