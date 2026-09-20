import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final String? apkDownloadUrl;
  final String releaseNotes;
  final String releaseTitle;
  final String? releaseDate;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    this.apkDownloadUrl,
    required this.releaseNotes,
    required this.releaseTitle,
    this.releaseDate,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _skippedVersionKey = 'skipped_update_version';

  static const String githubOwner = 'Sahandulmith';
  static const String githubRepo = 'Royal-Hnads-LMS';
  static const String fallbackReleaseUrl = 'https://github.com/$githubOwner/$githubRepo/releases';

  static String? _cachedVersion;

  /// Dynamically fetch current application version from PackageInfo
  static Future<String> getCurrentAppVersion() async {
    if (_cachedVersion != null && _cachedVersion!.isNotEmpty) {
      return _cachedVersion!;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _cachedVersion = info.version.trim();
        return _cachedVersion!;
      }
    } catch (e) {
      debugPrint('Error fetching package info: $e');
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _cachedVersion = info.version.trim();
        return _cachedVersion!;
      }
    } catch (_) {}

    return '1.0.0';
  }

  /// Version comparison helper
  static bool _isNewerVersion(String currentVersion, String remoteTag) {
    final cur = currentVersion.trim().isNotEmpty ? currentVersion : '1.0.0';
    String remote = remoteTag.toLowerCase().startsWith('v') ? remoteTag.substring(1) : remoteTag;
    String local = cur.toLowerCase().startsWith('v') ? cur.substring(1) : cur;

    remote = remote.replaceAll(RegExp(r'[^0-9.+]'), '');
    local = local.replaceAll(RegExp(r'[^0-9.+]'), '');

    final rParts = remote.split('+')[0].split('.');
    final lParts = local.split('+')[0].split('.');
    final maxLen = rParts.length > lParts.length ? rParts.length : lParts.length;

    for (int i = 0; i < maxLen; i++) {
      final rNum = i < rParts.length ? int.tryParse(rParts[i]) ?? 0 : 0;
      final lNum = i < lParts.length ? int.tryParse(lParts[i]) ?? 0 : 0;
      if (rNum > lNum) return true;
      if (lNum > rNum) return false;
    }
    return false;
  }

  /// Check for newer release from GitHub
  static Future<AppUpdateInfo> checkForUpdates({bool isManualCheck = false}) async {
    if (kIsWeb) {
      return AppUpdateInfo(
        hasUpdate: false,
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
        updateUrl: '',
        releaseNotes: 'Web is always up to date.',
        releaseTitle: 'Web Version',
      );
    }

    final currentVersion = await getCurrentAppVersion();

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'RoyalHandsLMS-Updater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return AppUpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          updateUrl: fallbackReleaseUrl,
          releaseNotes: 'Up to date.',
          releaseTitle: 'Latest Release',
        );
      }

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) {
        return AppUpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          updateUrl: fallbackReleaseUrl,
          releaseNotes: 'Up to date.',
          releaseTitle: 'Latest Release',
        );
      }

      for (final release in releases) {
        if (release is! Map) continue;
        if (release['draft'] == true) continue;

        final List<dynamic> assets = (release['assets'] as List<dynamic>?) ?? [];
        String? downloadUrl;

        for (final asset in assets) {
          if (asset is Map) {
            final name = ((asset['name'] as String?) ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        final String rawRemoteTag = (release['tag_name'] as String?) ?? '';
        final String remoteTag = (rawRemoteTag.startsWith('v') || rawRemoteTag.startsWith('V'))
            ? rawRemoteTag.substring(1)
            : rawRemoteTag;
        final String changelog = (release['body'] as String?) ?? 'General improvements and bug fixes.';
        final String htmlUrl = (release['html_url'] as String?) ?? fallbackReleaseUrl;
        final String rawCreatedAt = (release['created_at'] as String?) ?? '';

        String formattedDate = '';
        if (rawCreatedAt.isNotEmpty) {
          try {
            final dt = DateTime.parse(rawCreatedAt).toLocal();
            formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(dt);
          } catch (_) {
            formattedDate = rawCreatedAt;
          }
        }

        final bool hasUpdate = _isNewerVersion(currentVersion, remoteTag);
        final skippedVersion = await _storage.read(key: _skippedVersionKey);
        final isSkipped = !isManualCheck && (skippedVersion == remoteTag);

        return AppUpdateInfo(
          hasUpdate: hasUpdate && !isSkipped,
          currentVersion: currentVersion,
          latestVersion: remoteTag,
          updateUrl: htmlUrl,
          apkDownloadUrl: downloadUrl ?? htmlUrl,
          releaseNotes: changelog,
          releaseTitle: 'Version $remoteTag',
          releaseDate: formattedDate,
        );
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }

    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      updateUrl: fallbackReleaseUrl,
      releaseNotes: 'Up to date.',
      releaseTitle: 'Latest Release',
    );
  }

  /// Launch update URL in browser
  static Future<bool> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Download APK with progress and launch Android package installer via OpenFilex
  static Future<void> downloadAndInstallApk(
    String apkUrl, {
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        onError('Download failed with server code ${response.statusCode}');
        client.close();
        return;
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await response.stream.forEach((chunk) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        } else {
          onProgress(0.5);
        }
      });
      client.close();

      onProgress(1.0);

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/royal_hands_lms_update.apk');
      await apkFile.writeAsBytes(bytes);

      // Launch native Android Package Installer via OpenFilex directly without opening browser
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        debugPrint('OpenFilex result error: ${result.message}');
        onError('Installer launch error: ${result.message}');
      }
    } catch (e) {
      debugPrint('downloadAndInstallApk error: $e');
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<void> skipVersion(String version) async {
    await _storage.write(key: _skippedVersionKey, value: version);
  }
}
