enum UpdateAvailability {
  upToDate,
  optional,
  mandatory,
  unavailable,
}

class UpdateManifest {
  const UpdateManifest({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.apkUrl,
    required this.fallbackUrls,
    required this.releasePageUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });

  final String latestVersion;
  final String minSupportedVersion;
  final String apkUrl;
  final List<String> fallbackUrls;
  final String? releasePageUrl;
  final List<String> releaseNotes;
  final DateTime? publishedAt;

  List<String> get downloadCandidates {
    final List<String> values = <String>[apkUrl, ...fallbackUrls];
    if (releasePageUrl != null && releasePageUrl!.trim().isNotEmpty) {
      values.add(releasePageUrl!.trim());
    }

    final Set<String> dedup = <String>{};
    for (final String value in values) {
      final String cleaned = value.trim();
      if (cleaned.isNotEmpty) {
        dedup.add(cleaned);
      }
    }
    return dedup.toList(growable: false);
  }

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final String latestVersion =
        _readRequiredString(json, 'latest_version').trim();
    final String minSupportedVersion =
        _readRequiredString(json, 'min_supported_version').trim();
    final String apkUrl = _readRequiredString(json, 'apk_url').trim();
    final List<String> fallbackUrls = _readUrlList(json['apk_fallback_urls']);
    final List<String> releaseNotes = _readReleaseNotes(json['release_notes']);
    final String? releasePageUrl = _readOptionalString(
      json['release_page_url'],
    );

    DateTime? publishedAt;
    final dynamic publishedRaw = json['published_at'];
    if (publishedRaw is String && publishedRaw.trim().isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedRaw.trim());
    }

    if (latestVersion.isEmpty) {
      throw const FormatException('latest_version bos olamaz.');
    }
    if (minSupportedVersion.isEmpty) {
      throw const FormatException('min_supported_version bos olamaz.');
    }
    if (apkUrl.isEmpty) {
      throw const FormatException('apk_url bos olamaz.');
    }

    return UpdateManifest(
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
      apkUrl: apkUrl,
      fallbackUrls: fallbackUrls,
      releasePageUrl: releasePageUrl,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt,
    );
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is! String) {
      throw FormatException('$key alani string olmali.');
    }
    return value;
  }

  static List<String> _readReleaseNotes(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item is String ? item.trim() : '')
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  static String? _readOptionalString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final String cleaned = value.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  static List<String> _readUrlList(dynamic value) {
    if (value is String) {
      final String cleaned = value.trim();
      if (cleaned.isEmpty) {
        return const <String>[];
      }
      return <String>[cleaned];
    }
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item is String ? item.trim() : '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.availability,
    this.manifest,
  });

  final UpdateAvailability availability;
  final UpdateManifest? manifest;

  bool get isMandatory => availability == UpdateAvailability.mandatory;
  bool get isOptional => availability == UpdateAvailability.optional;
  bool get isUpToDate => availability == UpdateAvailability.upToDate;

  static const UpdateCheckResult unavailable = UpdateCheckResult(
    availability: UpdateAvailability.unavailable,
  );
}

int compareSemanticVersions(String left, String right) {
  final List<int> leftParts = _parseVersion(left);
  final List<int> rightParts = _parseVersion(right);
  final int maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (int i = 0; i < maxLength; i++) {
    final int leftValue = i < leftParts.length ? leftParts[i] : 0;
    final int rightValue = i < rightParts.length ? rightParts[i] : 0;
    if (leftValue > rightValue) {
      return 1;
    }
    if (leftValue < rightValue) {
      return -1;
    }
  }

  return 0;
}

List<int> _parseVersion(String rawVersion) {
  final String normalized = rawVersion.split('+').first.split('-').first.trim();
  if (normalized.isEmpty) {
    return const <int>[0];
  }

  return normalized.split('.').map((String part) {
    final RegExpMatch? match = RegExp(r'^\d+').firstMatch(part.trim());
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(0)!) ?? 0;
  }).toList();
}
