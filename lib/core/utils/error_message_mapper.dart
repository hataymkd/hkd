class ErrorMessageMapper {
  const ErrorMessageMapper._();

  static String toFriendlyTurkish(
    Object error, {
    String fallback = 'Islem sirasinda hata olustu. Lutfen tekrar deneyin.',
  }) {
    final String cleaned = _clean(error.toString());
    if (cleaned.isEmpty) {
      return fallback;
    }

    final String normalized = cleaned.toLowerCase();

    if (_containsAny(
      normalized,
      const <String>[
        'invalid jwt',
        'jwt',
        'not authenticated',
        'unauthorized',
        'permission denied',
      ],
    )) {
      return 'Oturum dogrulanamadi. Lutfen tekrar giris yapin.';
    }

    if (_containsAny(
      normalized,
      const <String>[
        'timeout',
        'socketexception',
        'network',
        'connection',
      ],
    )) {
      return 'Ag baglantisi kurulamadigi icin islem tamamlanamadi.';
    }

    if (_containsAny(
      normalized,
      const <String>[
        'no authenticated user found',
        'authenticated user',
      ],
    )) {
      return 'Oturum bulunamadi. Lutfen yeniden giris yapin.';
    }

    if (_containsAny(
      normalized,
      const <String>[
        'edge function returned invalid response',
        'invalid response',
      ],
    )) {
      return 'Sunucu yaniti gecersiz. Lutfen tekrar deneyin.';
    }

    if (_containsEnglishTechnicalTokens(normalized)) {
      return fallback;
    }

    return cleaned;
  }

  static String _clean(String raw) {
    String value = raw.trim();
    const List<String> prefixes = <String>[
      'Bad state: ',
      'Unsupported operation: ',
      'AuthException: ',
    ];

    for (final String prefix in prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
      }
    }

    return value;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final String needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsEnglishTechnicalTokens(String text) {
    return _containsAny(
      text,
      const <String>[
        'error',
        'failed',
        'invalid',
        'exception',
        'cannot',
        'unable',
      ],
    );
  }
}
