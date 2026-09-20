import 'dart:async';
import 'package:flutter/material.dart';
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

  Future<void> _startInAppUpdate() async {
    final targetUrl = widget.updateInfo.apkDownloadUrl ?? widget.updateInfo.updateUrl;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusText = 'Downloading update package... 0%';
      _hasError = false;
      _errorMessage = null;
    });

    await UpdateService.downloadAndInstallApk(
      targetUrl,
      onProgress: (double progress) {
        if (!mounted) return;
        final pct = (progress * 100).round().clamp(0, 100);
        setState(() {
          _downloadProgress = pct;
          if (pct >= 100) {
            _statusText = 'Launching Android Package Installer...';
          } else {
            _statusText = 'Downloading update package... $pct%';
          }
        });
      },
      onError: (String error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = error;
          _statusText = 'Download failed.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSubColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final cleanCurrentVersion = widget.updateInfo.currentVersion.split('+')[0];
    final cleanLatestVersion = widget.updateInfo.latestVersion.split('+')[0];

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

                      // Version Comparison Badge (Clean v1.0.0 -> v1.0.1 format)
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
                            if (cleanCurrentVersion.isNotEmpty && cleanCurrentVersion != 'Unknown') ...[
                              Text(
                                'v$cleanCurrentVersion',
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
                            ],
                            Text(
                              'v$cleanLatestVersion',
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
                                  style: TextStyle(
                                    color: _hasError ? Colors.redAccent : const Color(0xFF6366F1),
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
                                valueColor: AlwaysStoppedAnimation<Color>(_hasError ? Colors.redAccent : const Color(0xFF84CC16)),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent.withAlpha(80)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, height: 1.3),
                                ),
                              ),
                            ],
                            if (_hasError) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: _startInAppUpdate,
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('RETRY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        label: const Text('CLOSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textSubColor,
                                          side: BorderSide(color: textSubColor.withAlpha(80)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
