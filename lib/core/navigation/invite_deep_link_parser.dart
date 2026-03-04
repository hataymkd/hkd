String? extractInviteTokenFromUri(Uri? uri) {
  if (uri == null) {
    return null;
  }

  final String scheme = uri.scheme.toLowerCase();
  final List<String> rawSegments = uri.pathSegments
      .map((String segment) => segment.trim())
      .where((String segment) => segment.isNotEmpty)
      .toList();
  final List<String> normalizedSegments =
      rawSegments.map((String segment) => segment.toLowerCase()).toList();

  if (scheme == 'hkd') {
    final String host = uri.host.toLowerCase();
    final bool isInviteRoute =
        host == 'invite' || normalizedSegments.contains('invite');
    if (!isInviteRoute) {
      return null;
    }
    return _extractToken(uri, rawSegments, normalizedSegments);
  }

  if (scheme == 'https' || scheme == 'http') {
    if (!normalizedSegments.contains('invite')) {
      return null;
    }
    return _extractToken(uri, rawSegments, normalizedSegments);
  }

  return null;
}

String? _extractToken(
  Uri uri,
  List<String> rawSegments,
  List<String> normalizedSegments,
) {
  final String? queryToken = uri.queryParameters['token']?.trim();
  if (_isValidToken(queryToken)) {
    return queryToken;
  }

  final int inviteIndex = normalizedSegments.indexOf('invite');
  if (inviteIndex >= 0 && rawSegments.length > inviteIndex + 1) {
    final String pathToken = rawSegments[inviteIndex + 1].trim();
    if (_isValidToken(pathToken)) {
      return pathToken;
    }
  }

  return null;
}

bool _isValidToken(String? value) {
  if (value == null || value.isEmpty) {
    return false;
  }

  final RegExp tokenPattern = RegExp(r'^[A-Za-z0-9_-]{16,}$');
  return tokenPattern.hasMatch(value);
}
