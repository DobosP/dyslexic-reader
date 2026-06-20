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

/// Reading-focus mode — a single line-focus aid that auto-follows your reading
/// to keep your place. The modes are mutually exclusive: [highlight] (the
/// default) tints the sentence at the reading line as you scroll, while the
/// band styles paint a focus strip the text flows under, differing in how they
/// treat the surrounding text (tint the band, underline it, or dim above/below).
///
/// Strong evidence base: the CHI-2023 "Digital Reading Rulers" study found all
/// of these styles improved reading speed and comprehension, with the largest
/// gains for dyslexic readers, and no single style preferred by everyone — so
/// we offer the choice. (See docs/RESEARCH.md §1.)
enum ReadingRulerStyle {
  off('Off'),
  highlight('Highlight line'),
  bar('Tint band'),
  underline('Underline'),
  shade('Shade'),
  spotlight('Spotlight');

  const ReadingRulerStyle(this.label);

  final String label;

  /// Whether a focus band overlay should be painted — the band styles only, not
  /// [off] or the in-text [highlight].
  bool get isBand =>
      this == bar || this == underline || this == shade || this == spotlight;
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
    this.highlightMaxRows = 2,
    this.readerContinuous = false,
    this.rulerStyle = ReadingRulerStyle.highlight,
    this.rulerRows = 2,
    this.rulerCenter = 0.45,
    this.ttsVoiceName,
    this.ttsVoiceLocale,
    this.ttsPitch = 1.0,
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

  /// How many rendered rows the smart highlight spans at once (1, 2, or 3).
  final int highlightMaxRows;

  /// Continuous scrolling text instead of fixed pages.
  final bool readerContinuous;

  /// The active reading-focus mode (defaults to [ReadingRulerStyle.highlight]).
  /// The highlight and band styles are mutually exclusive.
  final ReadingRulerStyle rulerStyle;

  /// How many lines tall the reading-focus band / highlight is (1–3).
  final int rulerRows;

  /// Vertical position of the focus band as a fraction of the viewport (0–1).
  /// The band auto-follows reading at this resting line; text scrolls under it.
  final double rulerCenter;

  /// Chosen text-to-speech voice (engine voice name); null = engine default.
  final String? ttsVoiceName;

  /// BCP-47 locale of the chosen voice (paired with [ttsVoiceName]).
  final String? ttsVoiceLocale;

  /// Read-aloud pitch (0.5–2.0, 1.0 = normal).
  final double ttsPitch;

  // --- Derived values used by the renderer ---

  /// True when the focus mode is the in-text line highlight (the default).
  bool get lineHighlight => rulerStyle == ReadingRulerStyle.highlight;

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
    int? highlightMaxRows,
    bool? readerContinuous,
    ReadingRulerStyle? rulerStyle,
    int? rulerRows,
    double? rulerCenter,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    double? ttsPitch,
    bool clearTtsVoice = false,
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
      highlightMaxRows: highlightMaxRows ?? this.highlightMaxRows,
      readerContinuous: readerContinuous ?? this.readerContinuous,
      rulerStyle: rulerStyle ?? this.rulerStyle,
      rulerRows: rulerRows ?? this.rulerRows,
      rulerCenter: rulerCenter ?? this.rulerCenter,
      ttsVoiceName: clearTtsVoice ? null : (ttsVoiceName ?? this.ttsVoiceName),
      ttsVoiceLocale: clearTtsVoice ? null : (ttsVoiceLocale ?? this.ttsVoiceLocale),
      ttsPitch: ttsPitch ?? this.ttsPitch,
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
        'highlightMaxRows': highlightMaxRows,
        'readerContinuous': readerContinuous,
        'rulerStyle': rulerStyle.name,
        'rulerRows': rulerRows,
        'rulerCenter': rulerCenter,
        'ttsVoiceName': ttsVoiceName,
        'ttsVoiceLocale': ttsVoiceLocale,
        'ttsPitch': ttsPitch,
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
      highlightMaxRows:
          (j['highlightMaxRows'] as num?)?.toInt() ?? d.highlightMaxRows,
      readerContinuous: j['readerContinuous'] as bool? ?? d.readerContinuous,
      rulerStyle: _enumByName(ReadingRulerStyle.values, j['rulerStyle'], d.rulerStyle),
      rulerRows: (j['rulerRows'] as num?)?.toInt() ?? d.rulerRows,
      rulerCenter: _toDouble(j['rulerCenter'], d.rulerCenter),
      ttsVoiceName: j['ttsVoiceName'] as String?,
      ttsVoiceLocale: j['ttsVoiceLocale'] as String?,
      ttsPitch: _toDouble(j['ttsPitch'], d.ttsPitch),
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
