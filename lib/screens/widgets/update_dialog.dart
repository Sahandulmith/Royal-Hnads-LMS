import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../../core/services/update_service.dart';

class UpdateAvailableDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateAvailableDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateAvailableDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _statusText = 'Preparing download...';
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startInAppUpdate() async {
    final rawApkUrl = widget.updateInfo.apkDownloadUrl ?? widget.updateInfo.updateUrl;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusText = 'Resolving download package...';
      _hasError = false;
      _errorMessage = null;
    });

    final apkUrl = await UpdateService.resolveDirectApkUrl(rawApkUrl);

    if (!mounted) return;

    // If URL is not an APK or direct download, fallback directly to external browser launcher
    final isApkOrDirect = apkUrl.toLowerCase().contains('.apk') ||
        apkUrl.contains('amazonaws.com') ||
        apkUrl.contains('firebasestorage') ||
        apkUrl.contains('github.com/releases/download');

    if (!isApkOrDirect) {
      _fallbackToBrowserDownload(apkUrl);
      return;
    }

    setState(() {
      _statusText = 'Starting in-app download...';
    });

    // Timeout check if download stays at 0% for too long
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 18), () {
      if (mounted && _isDownloading && _downloadProgress == 0 && !_hasError) {
        debugPrint('OTA Update timed out at 0%. Falling back to browser download.');
        setState(() {
          _hasError = true;
          _errorMessage = 'In-app download slow/unresponsive. Opening browser...';
        });
        _fallbackToBrowserDownload(apkUrl);
      }
    });

    try {
      _otaSubscription = UpdateService.downloadAndInstallOTA(apkUrl).listen(
        (OtaEvent event) {
          if (!mounted) return;

          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final parsed = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _downloadProgress = parsed.clamp(0, 100);
                _statusText = 'Downloading update package... $_downloadProgress%';
              });
              if (_downloadProgress > 0) {
                timeoutTimer?.cancel();
              }
              break;
            case OtaStatus.INSTALLING:
              timeoutTimer?.cancel();
              setState(() {
                _downloadProgress = 100;
                _statusText = 'Launching Android Package Installer...';
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _statusText = 'Download already in progress...';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              timeoutTimer?.cancel();
              setState(() {
                _hasError = true;
                _errorMessage = 'Permission denied to install unknown apps.';
                _statusText = 'Installation permission required.';
              });
              break;
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            default:
              timeoutTimer?.cancel();
              setState(() {
                _hasError = true;
                _errorMessage = 'In-app download failed. Opening browser download...';
              });
              _fallbackToBrowserDownload(apkUrl);
              break;
          }
        },
        onError: (dynamic error) {
          timeoutTimer?.cancel();
          if (!mounted) return;
          debugPrint('OTA Update error: $error');
          setState(() {
            _hasError = true;
            _errorMessage = 'In-app update encountered an issue.';
          });
          _fallbackToBrowserDownload(apkUrl);
        },
      );
    } catch (e) {
      timeoutTimer?.cancel();
      debugPrint('Failed to initialize OTA download stream: $e');
      _fallbackToBrowserDownload(apkUrl);
    }
  }

  Future<void> _fallbackToBrowserDownload(String url) async {
    await UpdateService.launchUpdateUrl(url);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSubColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        alignment: Alignment.topRight,
        clipBehavior: Clip.none,
        children: [
          // Main Dialog Card Container
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Banner with Gradient & Illustration
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background decorative shapes
                      Positioned(
                        top: 20,
                        left: 30,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        right: 40,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),

                      // Graphic Icon
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withAlpha(60),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isDownloading ? Icons.system_update_alt_rounded : Icons.rocket_launch_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Body Details Section
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 24),
                  child: Column(
                    children: [
                      Text(
                        _isDownloading ? 'Updating Royal Hands' : 'New Update Available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDownloading
                            ? 'Downloading and preparing the newest app features & performance updates.'
                            : 'An updated version is available. Upgrade now for the best experience.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSubColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Version Comparison Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'v${widget.updateInfo.currentVersion}',
                              style: TextStyle(
                                color: textSubColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF6366F1)),
                            ),
                            Text(
                              'v${widget.updateInfo.latestVersion}',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. IN-APP DOWNLOADING PROGRESS SECTION
                      if (_isDownloading) ...[
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _hasError ? Colors.redAccent : textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_downloadProgress%',
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _downloadProgress / 100.0,
                                minHeight: 10,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF84CC16)),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => _fallbackToBrowserDownload(widget.updateInfo.apkDownloadUrl ?? widget.updateInfo.updateUrl),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: const Text('Open Browser Download Instead', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ] else ...[
                        // GET UPDATE NOW Green Capsule Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _startInAppUpdate,
                            icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                            label: const Text(
                              'GET UPDATE NOW',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF84CC16),
                              foregroundColor: const Color(0xFF1E3A8A),
                              elevation: 4,
                              shadowColor: const Color(0xFF84CC16).withAlpha(100),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Remind Me Later Button
                        TextButton(
                          onPressed: () {
                            UpdateService.skipVersion(widget.updateInfo.latestVersion);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Remind Me Later',
                            style: TextStyle(
                              color: textSubColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating (X) Close Button at Top Right
          Positioned(
            top: -12,
            right: -12,
            child: GestureDetector(
              onTap: () {
                _otaSubscription?.cancel();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
