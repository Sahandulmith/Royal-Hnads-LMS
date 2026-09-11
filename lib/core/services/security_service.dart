import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class SecurityService {
  static bool _isSecureModeEnabled = false;

  static bool get isSecureModeEnabled => _isSecureModeEnabled;

  /// Enables screenshot and screen recording protection at the OS native level
  /// - Android: Enables FLAG_SECURE (turns recordings completely black & disables screenshots)
  /// - iOS: Enables screenshot prevention & screen capture monitoring
  static Future<void> enableSecureScreen() async {
    try {
      if (!kIsWeb) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
        _isSecureModeEnabled = true;
        debugPrint('SecurityService: Screen Recording & Screenshot Protection ENABLED');
      }
    } catch (e) {
      debugPrint('SecurityService error enabling screen protector: $e');
    }
  }

  /// Disables screenshot protection when leaving secure screens
  static Future<void> disableSecureScreen() async {
    try {
      if (!kIsWeb) {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithColorOff();
        _isSecureModeEnabled = false;
        debugPrint('SecurityService: Screen Protection Disabled');
      }
    } catch (e) {
      debugPrint('SecurityService error disabling screen protector: $e');
    }
  }

  /// Checks if screen recording is currently active on the device (iOS/Android)
  static Future<bool> isScreenRecordingActive() async {
    try {
      if (!kIsWeb) {
        return await ScreenProtector.isRecording();
      }
    } catch (e) {
      debugPrint('SecurityService error checking screen recording status: $e');
    }
    return false;
  }

  /// Builds a background privacy shield widget whenever the app moves to background state
  static Widget wrapWithPrivacyShield({
    required BuildContext context,
    required Widget child,
    required bool isAppPaused,
  }) {
    if (!isAppPaused) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Protected LMS Content Hidden',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Screen recording and content capture are prohibited.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
