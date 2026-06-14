/// Case-insensitive in-document search.
///
/// Returns the character offsets of every occurrence of [query] in [text]
/// (left to right, non-overlapping), capped at [cap] to keep very large
/// documents responsive. Queries shorter than 2 characters return no matches.
List<int> findMatches(String text, String query, {int cap = 1000}) {
  final q = query.trim();
  if (q.length < 2) return const [];
  final hay = text.toLowerCase();
  final needle = q.toLowerCase();
  final out = <int>[];
  var i = hay.indexOf(needle);
  while (i >= 0 && out.length < cap) {
    out.add(i);
    i = hay.indexOf(needle, i + needle.length);
  }
  return out;
}
