/// "Bionic"/fixation-style reading: bold the leading portion of each word.
///
/// IMPORTANT: this is an opt-in display mode, not an evidence-based aid.
/// Independent tests found no speed or comprehension benefit (see
/// docs/RESEARCH.md). It is included only because some users like it.
class Bionic {
  Bionic._();

  /// Number of leading characters of [word] to embolden. Scales ~40% with word
  /// length (a common heuristic), always at least 1 for non-empty words.
  static int boldPrefixLength(String word) {
    final n = word.length;
    if (n <= 1) return n;
    return (n * 0.4).round().clamp(1, n);
  }
}
