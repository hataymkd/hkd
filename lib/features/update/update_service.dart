import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hkd/core/env.dart';
import 'package:hkd/features/update/update_model.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  UpdateService({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 5),
    String? manifestUrlOverride,
  })  : _httpClient = httpClient ?? http.Client(),
        _timeout = timeout,
        _manifestUrlOverride = manifestUrlOverride;

  final http.Client _httpClient;
  final Duration _timeout;
  final String? _manifestUrlOverride;

  Future<UpdateCheckResult> checkForUpdate() async {
    final String manifestUrl = _resolveManifestUrl();
    if (manifestUrl.isEmpty) {
      return UpdateCheckResult.unavailable;
    }

    final Uri? manifestUri = Uri.tryParse(manifestUrl);
    if (manifestUri == null ||
        (manifestUri.scheme != 'https' && manifestUri.scheme != 'http')) {
      return UpdateCheckResult.unavailable;
    }

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version.trim();
      if (currentVersion.isEmpty) {
        return UpdateCheckResult.unavailable;
      }

      final http.Response response = await _httpClient.get(
        manifestUri,
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return UpdateCheckResult.unavailable;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return UpdateCheckResult.unavailable;
      }

      final UpdateManifest manifest =
          UpdateManifest.fromJson(decoded.cast<String, dynamic>());

      final int minComparison =
          compareSemanticVersions(currentVersion, manifest.minSupportedVersion);
      if (minComparison < 0) {
        return UpdateCheckResult(
          availability: UpdateAvailability.mandatory,
          manifest: manifest,
        );
      }

      final int latestComparison =
          compareSemanticVersions(currentVersion, manifest.latestVersion);
      if (latestComparison < 0) {
        return UpdateCheckResult(
          availability: UpdateAvailability.optional,
          manifest: manifest,
        );
      }

      return UpdateCheckResult(
        availability: UpdateAvailability.upToDate,
        manifest: manifest,
      );
    } on TimeoutException {
      return UpdateCheckResult.unavailable;
    } on SocketException {
      return UpdateCheckResult.unavailable;
    } on http.ClientException {
      return UpdateCheckResult.unavailable;
    } on FormatException {
      return UpdateCheckResult.unavailable;
    } catch (_) {
      return UpdateCheckResult.unavailable;
    }
  }

  String _resolveManifestUrl() {
    final String overrideValue = (_manifestUrlOverride ?? '').trim();
    if (overrideValue.isNotEmpty) {
      return overrideValue;
    }
    return Env.updateManifestUrl.trim();
  }
}
