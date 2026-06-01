import 'dart:convert';

/// Selectable reading font. [family] must match a family declared in
/// pubspec.yaml; `null` means the platform default sans-serif.
///
/// Note: the evidence base shows spacing helps far more than any "dyslexia
/// font" (see docs/RESEARCH.md). These are offered as options, with a clean
/// legible sans-serif (Atkinson Hyperlegible) as the default.
enum ReadingFontFamily {
  atkinsonHyperlegible('Atkinson Hyperlegible', 'AtkinsonHyperlegible'),
  lexend('Lexend', 'Lexend'),
  openDyslexic('OpenDyslexic', 'OpenDyslexic'),
  system('System default', null);

  const ReadingFontFamily(this.label, this.family);

  final String label;
  final String? family;
}

/// Reading background/foreground theme. Pure white is intentionally avoided
/// (British Dyslexia Association guidance).
enum ReadingThemeId {
  cream('Cream'),
  sepia('Sepia'),
  offWhite('Off-white'),
  dark('Dark'),
  highContrast('High contrast');

  const ReadingThemeId(this.label);

  final String label;
}

/// Immutable bundle of user reading preferences. Persisted as JSON.
///
/// Spacing values are expressed as multiples of the font size ("em") so they
/// scale sensibly when the user changes text size. Defaults follow WCAG 1.4.12
/// and the BDA style guide (line height 1.5, generous letter/word spacing,
/// ~66 character line length, left-aligned, off-white background).
class ReadingPrefs {
  const ReadingPrefs({
    this.fontFamily = ReadingFontFamily.atkinsonHyperlegible,
    this.themeId = ReadingThemeId.cream,
    this.fontSizeSp = 20,
    this.letterSpacingEm = 0.04,
    this.wordSpacingEm = 0.08,
    this.lineHeight = 1.5,
    this.paragraphSpacingEm = 1.0,
    this.maxLineChars = 66,
    this.bionicEnabled = false,
    this.sentencePacing = false,
    this.readingWpm = 180,
  });

  final ReadingFontFamily fontFamily;
  final ReadingThemeId themeId;

  /// Logical font size in sp.
  final double fontSizeSp;

  /// Inter-letter spacing as a multiple of [fontSizeSp].
  final double letterSpacingEm;

  /// Extra inter-word spacing as a multiple of [fontSizeSp].
  final double wordSpacingEm;

  /// Line height as a multiple of font size (1.5 == 150%).
  final double lineHeight;

  /// Vertical gap between paragraphs as a multiple of [fontSizeSp].
  final double paragraphSpacingEm;

  /// Target line length in characters (controls max text column width).
  final double maxLineChars;

  /// Optional "bionic"/fixation bolding of word prefixes. Off by default — the
  /// technique has weak/negative evidence (see docs/RESEARCH.md) and is offered
  /// only as an opt-in display mode.
  final bool bionicEnabled;

  /// When on, each sentence is shown as its own spaced block (pacing aid).
  final bool sentencePacing;

  /// Read-along pace in words per minute (for the smart highlighter).
  final double readingWpm;

  // --- Derived values used by the renderer ---
  double get letterSpacingPx => letterSpacingEm * fontSizeSp;
  double get wordSpacingPx => wordSpacingEm * fontSizeSp;
  double get paragraphSpacingPx => paragraphSpacingEm * fontSizeSp;

  /// Approximate column width for the target line length. ~0.5em per character
  /// is a reasonable average for proportional fonts; clamped to sane bounds.
  double get maxLineWidthPx => (maxLineChars * fontSizeSp * 0.5).clamp(240.0, 960.0);

  ReadingPrefs copyWith({
    ReadingFontFamily? fontFamily,
    ReadingThemeId? themeId,
    double? fontSizeSp,
    double? letterSpacingEm,
    double? wordSpacingEm,
    double? lineHeight,
    double? paragraphSpacingEm,
    double? maxLineChars,
    bool? bionicEnabled,
    bool? sentencePacing,
    double? readingWpm,
  }) {
    return ReadingPrefs(
      fontFamily: fontFamily ?? this.fontFamily,
      themeId: themeId ?? this.themeId,
      fontSizeSp: fontSizeSp ?? this.fontSizeSp,
      letterSpacingEm: letterSpacingEm ?? this.letterSpacingEm,
      wordSpacingEm: wordSpacingEm ?? this.wordSpacingEm,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacingEm: paragraphSpacingEm ?? this.paragraphSpacingEm,
      maxLineChars: maxLineChars ?? this.maxLineChars,
      bionicEnabled: bionicEnabled ?? this.bionicEnabled,
      sentencePacing: sentencePacing ?? this.sentencePacing,
      readingWpm: readingWpm ?? this.readingWpm,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily.name,
        'themeId': themeId.name,
        'fontSizeSp': fontSizeSp,
        'letterSpacingEm': letterSpacingEm,
        'wordSpacingEm': wordSpacingEm,
        'lineHeight': lineHeight,
        'paragraphSpacingEm': paragraphSpacingEm,
        'maxLineChars': maxLineChars,
        'bionicEnabled': bionicEnabled,
        'sentencePacing': sentencePacing,
        'readingWpm': readingWpm,
      };

  factory ReadingPrefs.fromJson(Map<String, dynamic> j) {
    const d = ReadingPrefs();
    return ReadingPrefs(
      fontFamily: _enumByName(ReadingFontFamily.values, j['fontFamily'], d.fontFamily),
      themeId: _enumByName(ReadingThemeId.values, j['themeId'], d.themeId),
      fontSizeSp: _toDouble(j['fontSizeSp'], d.fontSizeSp),
      letterSpacingEm: _toDouble(j['letterSpacingEm'], d.letterSpacingEm),
      wordSpacingEm: _toDouble(j['wordSpacingEm'], d.wordSpacingEm),
      lineHeight: _toDouble(j['lineHeight'], d.lineHeight),
      paragraphSpacingEm: _toDouble(j['paragraphSpacingEm'], d.paragraphSpacingEm),
      maxLineChars: _toDouble(j['maxLineChars'], d.maxLineChars),
      bionicEnabled: j['bionicEnabled'] as bool? ?? d.bionicEnabled,
      sentencePacing: j['sentencePacing'] as bool? ?? d.sentencePacing,
      readingWpm: _toDouble(j['readingWpm'], d.readingWpm),
    );
  }

  String encode() => jsonEncode(toJson());

  factory ReadingPrefs.decode(String s) =>
      ReadingPrefs.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

double _toDouble(Object? v, double fallback) =>
    v is num ? v.toDouble() : fallback;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
