import 'package:flutter/material.dart';
import 'package:hkd/features/update/update_model.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateManifest manifest,
  required bool isMandatory,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !isMandatory,
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: !isMandatory,
        child: AlertDialog(
          title: Text(
            isMandatory ? 'Zorunlu Guncelleme' : 'Yeni Surum Hazir',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Son surum: ${manifest.latestVersion}'),
                const SizedBox(height: 10),
                if (manifest.releaseNotes.isNotEmpty) ...<Widget>[
                  const Text(
                    'Yenilikler',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...manifest.releaseNotes.map(
                    (String note) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('- $note'),
                    ),
                  ),
                ] else
                  const Text(
                    'Yeni surum mevcut. Guncelleme yapmaniz onerilir.',
                  ),
                if (isMandatory) ...<Widget>[
                  const SizedBox(height: 10),
                  const Text(
                    'Devam etmek icin uygulamayi guncellemeniz gerekiyor.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Sonra'),
              ),
            if (manifest.releasePageUrl != null &&
                manifest.releasePageUrl!.trim().isNotEmpty)
              TextButton(
                onPressed: () async {
                  await _openDownloadLinks(
                    context: dialogContext,
                    rawUrls: <String>[manifest.releasePageUrl!.trim()],
                  );
                },
                child: const Text('Surum Sayfasi'),
              ),
            ElevatedButton(
              onPressed: () async {
                final bool opened = await _openDownloadLinks(
                  context: dialogContext,
                  rawUrls: manifest.downloadCandidates,
                );
                if (opened && dialogContext.mounted && !isMandatory) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Indir'),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _openDownloadLinks({
  required BuildContext context,
  required List<String> rawUrls,
}) async {
  for (final String rawUrl in rawUrls) {
    final Uri? uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      continue;
    }

    final bool launched = await _launchUriWithFallback(uri);
    if (launched) {
      return true;
    }
  }

  if (context.mounted) {
    _showSnackbar(context, 'Indirme sayfasi acilamadi. Lutfen tekrar deneyin.');
  }
  return false;
}

void _showSnackbar(BuildContext context, String message) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  messenger.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<bool> _launchUriWithFallback(Uri uri) async {
  final List<LaunchMode> modes = <LaunchMode>[
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
  ];

  for (final LaunchMode mode in modes) {
    try {
      final bool launched = await launchUrl(uri, mode: mode);
      if (launched) {
        return true;
      }
    } catch (_) {
      continue;
    }
  }

  return false;
}
