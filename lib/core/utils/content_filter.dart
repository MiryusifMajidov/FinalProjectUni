/// First-pass profanity screen for user-generated text (chat messages).
///
/// App Store guideline 1.2 requires apps with user-generated content to
/// filter objectionable material before it is published. This class is that
/// first pass and nothing more: the word list is short, obvious and
/// deliberately non-exhaustive, and it does not understand context, intent
/// or evasion beyond simple letter substitution. It is NOT a moderation
/// system — real moderation is the report flow (reports collection, reviewed
/// server-side) plus user blocking.
class ContentFilter {
  ContentFilter._();

  /// Common profanity in the app's main chat languages. Lowercase, already
  /// normalized (see [_normalize]).
  static const Set<String> _words = {
    // English
    'fuck', 'fucker', 'motherfucker', 'shit', 'bullshit', 'bitch', 'cunt',
    'asshole', 'bastard', 'dick', 'whore', 'slut', 'wanker', 'retard',
    'nigger', 'faggot',
    // Azerbaijani
    'sik', 'sikim', 'sikdir', 'qəhbə', 'götverən', 'dəyyus', 'pezevəng',
    'gicbaş', 'yavşaq',
    // Turkish
    'amk', 'amcık', 'orospu', 'piç', 'yarrak', 'sikerim', 'sikeyim',
    'oruspu', 'göt',
    // Russian
    'блядь', 'блять', 'сука', 'хуй', 'нахуй', 'пизда', 'ебать', 'ебал',
    'мудак', 'пидор', 'гандон',
  };

  /// Suffixes allowed after a listed word ("fucking", "bitches"). Kept to an
  /// explicit list so ordinary words that merely start with a listed word
  /// ("assist", "dickens") are not flagged.
  static const Set<String> _suffixes = {'s', 'es', 'ed', 'er', 'ers', 'ing'};

  /// Basic letter substitution used to dodge filters.
  static const Map<String, String> _substitutions = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '@': 'a',
  };

  /// A word: Latin (incl. Azerbaijani/Turkish diacritics and ə), Cyrillic,
  /// digits and `@`, so substituted spellings stay a single token.
  static final RegExp _token =
      RegExp(r'[A-Za-z0-9@À-ɏəЀ-ӿ]+');

  /// True when [text] contains no listed word.
  static bool isClean(String text) {
    for (final match in _token.allMatches(text)) {
      if (_isProfane(match[0]!)) return false;
    }
    return true;
  }

  /// Returns [text] with every listed word masked by asterisks.
  static String sanitize(String text) => text.replaceAllMapped(
        _token,
        (m) => _isProfane(m[0]!) ? '*' * m[0]!.length : m[0]!,
      );

  static bool _isProfane(String rawToken) {
    final token = _normalize(rawToken);
    if (token.isEmpty) return false;
    if (_words.contains(token)) return true;
    for (final word in _words) {
      if (token.length > word.length &&
          token.startsWith(word) &&
          _suffixes.contains(token.substring(word.length))) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String rawToken) {
    final buffer = StringBuffer();
    for (final rune in rawToken.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_substitutions[ch] ?? ch);
    }
    return buffer.toString();
  }
}
