import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final String? apkDownloadUrl;
  final String releaseNotes;
  final String releaseTitle;
  final DateTime? publishedAt;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    this.apkDownloadUrl,
    required this.releaseNotes,
    required this.releaseTitle,
    this.publishedAt,
  });
}

class UpdateService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _skippedVersionKey = 'skipped_update_version';
  
  // GitHub repository configuration
  static const String githubOwner = 'Sahandulmith';
  static const String githubRepo = 'Royal-Hnads-LMS';
  static const String fallbackReleaseUrl = 'https://github.com/$githubOwner/$githubRepo/releases';
  
  // Optional: Personal Access Token (PAT) with read permission for Private Repositories
  static const String? githubToken = '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'; // Set PAT here e.g. 'github_pat_...' if using GitHub API for private repos

  /// Get current app version from package_info_plus
  static Future<String> getCurrentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : '1.0.0';
    } catch (e) {
      debugPrint('Error reading package info: $e');
      return '1.0.0';
    }
  }

  /// Check GitHub Releases for newer version
  static Future<AppUpdateInfo> checkForUpdates({bool isManualCheck = false}) async {
    final currentVersion = await getCurrentAppVersion();

    try {
      // 1. Try fetching from GitHub Releases API
      final apiUrl = Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest');
      final Map<String, String> headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'RoyalHandsLMS-App',
      };

      if (githubToken != null && githubToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $githubToken';
      }

      final response = await http.get(apiUrl, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawTag = (data['tag_name'] as String? ?? '1.0.0').trim();
        final latestVersion = _cleanVersionTag(rawTag);
        final htmlUrl = (data['html_url'] as String? ?? fallbackReleaseUrl).trim();
        final releaseTitle = (data['name'] as String? ?? 'Version $latestVersion').trim();
        final releaseNotes = (data['body'] as String? ?? 'Bug fixes and performance improvements.').trim();

        // Extract direct APK asset link if available in GitHub release assets
        String? apkUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (var asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              final assetApiUrl = asset['url'] as String?;
              final browserUrl = asset['browser_download_url'] as String?;
              
              if (assetApiUrl != null && githubToken != null && githubToken!.isNotEmpty) {
                apkUrl = await resolveDirectApkUrl(assetApiUrl);
              }
              apkUrl ??= browserUrl;
              break;
            }
          }
        }

        final isHigher = _isVersionHigher(latestVersion, currentVersion);

        // Check if user previously skipped this specific update version (for auto-popup)
        final skippedVersion = await _storage.read(key: _skippedVersionKey);
        final isSkipped = !isManualCheck && (skippedVersion == latestVersion);

        final hasUpdate = isHigher && !isSkipped;

        return AppUpdateInfo(
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          updateUrl: htmlUrl,
          apkDownloadUrl: apkUrl ?? htmlUrl,
          releaseNotes: releaseNotes,
          releaseTitle: releaseTitle,
        );
      }
    } catch (e) {
      debugPrint('GitHub Release check exception: $e');
    }

    // 2. Fallback check via Firebase Firestore config document
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('version').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final latestVersion = _cleanVersionTag(data['latest_version'] ?? '1.0.0');
        final updateUrl = data['update_url'] ?? fallbackReleaseUrl;
        final releaseNotes = data['release_notes'] ?? 'General performance updates.';
        final releaseTitle = data['release_title'] ?? 'Version $latestVersion';

        final isHigher = _isVersionHigher(latestVersion, currentVersion);
        final skippedVersion = await _storage.read(key: _skippedVersionKey);
        final isSkipped = !isManualCheck && (skippedVersion == latestVersion);

        return AppUpdateInfo(
          hasUpdate: isHigher && !isSkipped,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          updateUrl: updateUrl,
          apkDownloadUrl: data['apk_url'] ?? updateUrl,
          releaseNotes: releaseNotes,
          releaseTitle: releaseTitle,
        );
      }
    } catch (e) {
      debugPrint('Firestore fallback version check error: $e');
    }

    // Default response when no update is available
    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      updateUrl: fallbackReleaseUrl,
      releaseNotes: 'Your app is up to date.',
      releaseTitle: 'Latest Version',
    );
  }

  /// Mark specific version as skipped to prevent auto-showing on every app launch
  static Future<void> skipVersion(String version) async {
    await _storage.write(key: _skippedVersionKey, value: version);
  }

  /// Launch update URL in external web browser or download APK
  static Future<bool> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching update URL with externalApplication: $e');
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (err) {
        debugPrint('Error launching update URL fallback: $err');
      }
    }
    return false;
  }

  /// Resolves direct downloadable URL for an APK asset (handles GitHub private repo 302 redirects)
  static Future<String> resolveDirectApkUrl(String assetApiUrlOrBrowserUrl) async {
    if (assetApiUrlOrBrowserUrl.isEmpty) return assetApiUrlOrBrowserUrl;

    if (assetApiUrlOrBrowserUrl.contains('amazonaws.com') ||
        assetApiUrlOrBrowserUrl.contains('firebasestorage')) {
      return assetApiUrlOrBrowserUrl;
    }

    if (githubToken != null && githubToken!.isNotEmpty && assetApiUrlOrBrowserUrl.contains('api.github.com')) {
      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(assetApiUrlOrBrowserUrl))
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $githubToken',
            'Accept': 'application/octet-stream',
            'User-Agent': 'RoyalHandsLMS-App',
          });

        final response = await client.send(request).timeout(const Duration(seconds: 8));
        if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307) {
          final redirectUrl = response.headers['location'];
          if (redirectUrl != null && redirectUrl.isNotEmpty) {
            debugPrint('Resolved direct APK download redirect URL successfully.');
            return redirectUrl;
          }
        }
      } catch (e) {
        debugPrint('Error resolving direct APK redirect URL: $e');
      }
    }

    return assetApiUrlOrBrowserUrl;
  }

  /// Download and execute OTA update with in-app progress stream
  static Stream<OtaEvent> downloadAndInstallOTA(String apkUrl) {
    try {
      return OtaUpdate().execute(
        apkUrl,
        destinationFilename: 'royal_hands_lms_update.apk',
      );
    } catch (e) {
      debugPrint('Error triggering OTA update stream: $e');
      rethrow;
    }
  }

  /// Clean raw tag string e.g. "v1.0.1-beta" -> "1.0.1"
  static String _cleanVersionTag(String tag) {
    String clean = tag.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    if (clean.contains('-')) {
      clean = clean.split('-').first.trim();
    }
    if (clean.contains('+')) {
      clean = clean.split('+').first.trim();
    }
    return clean;
  }

  /// Compare two semantic version strings (e.g. "1.0.1" vs "1.0.0")
  /// Returns true ONLY if candidateVersion is strictly higher than currentVersion
  static bool _isVersionHigher(String candidateVersion, String currentVersion) {
    final candClean = _cleanVersionTag(candidateVersion);
    final currClean = _cleanVersionTag(currentVersion);

    if (candClean == currClean) return false;

    final candParts = candClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currParts = currClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = candParts.length > currParts.length ? candParts.length : currParts.length;

    for (int i = 0; i < maxLength; i++) {
      final candPart = i < candParts.length ? candParts[i] : 0;
      final currPart = i < currParts.length ? currParts[i] : 0;

      if (candPart > currPart) return true;
      if (candPart < currPart) return false;
    }

    return false;
  }
}
