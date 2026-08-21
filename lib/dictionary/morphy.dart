/// WordNet's "Morphy": turns a word as written into the forms the dictionary
/// actually stores.
///
/// WordNet indexes base forms only — `conversation`, not `conversations`;
/// `run`, not `ran`. A reader long-presses whatever is on the page, so every
/// lookup has to be reduced first.
///
/// Two stages, in WordNet's own order:
///  1. the exception lists shipped with WordNet (`geese` -> `goose`), and
///  2. the detachment rules below, which strip regular endings.
///
/// Both stages produce *candidates*. Whether a candidate is a real word is
/// settled by looking it up, not here.
abstract final class Morphy {
  /// Suffix rules per part of speech, in the order WordNet applies them.
  static const _rules = <String, List<(String, String)>>{
    'n': [
      ('ses', 's'),
      ('xes', 'x'),
      ('zes', 'z'),
      ('ches', 'ch'),
      ('shes', 'sh'),
      ('men', 'man'),
      ('ies', 'y'),
      ('s', ''),
    ],
    'v': [
      ('ies', 'y'),
      ('es', 'e'),
      ('es', ''),
      ('ed', 'e'),
      ('ed', ''),
      ('ing', 'e'),
      ('ing', ''),
      ('s', ''),
    ],
    'a': [('er', ''), ('est', ''), ('er', 'e'), ('est', 'e')],
    'r': [],
  };

  static const partsOfSpeech = ['n', 'v', 'a', 'r'];

  /// Candidate base forms for [word] as [pos], most likely first.
  ///
  /// The word itself always comes first: plenty of words that look inflected
  /// aren't (`bus` is not the plural of `bu`).
  static List<String> candidates(String word, String pos) {
    final lower = word.toLowerCase();
    final out = <String>[lower];

    for (final (suffix, replacement)
        in _rules[pos] ?? const <(String, String)>[]) {
      if (!lower.endsWith(suffix)) continue;
      // Never strip a word down to nothing or to a single letter.
      final stem =
          lower.substring(0, lower.length - suffix.length) + replacement;
      if (stem.length < 2) continue;
      if (!out.contains(stem)) out.add(stem);
    }

    // Doubled consonant before -ing/-ed: "running" -> "run", "stopped" -> "stop".
    final undoubled = _undoubleConsonant(lower);
    if (undoubled != null && !out.contains(undoubled)) out.add(undoubled);

    return out;
  }

  static String? _undoubleConsonant(String word) {
    for (final suffix in const ['ing', 'ed']) {
      if (!word.endsWith(suffix)) continue;
      final stem = word.substring(0, word.length - suffix.length);
      if (stem.length < 3) continue;
      final last = stem[stem.length - 1];
      final secondLast = stem[stem.length - 2];
      if (last == secondLast && !'aeiou'.contains(last)) {
        return stem.substring(0, stem.length - 1);
      }
    }
    return null;
  }
}
