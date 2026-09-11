import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceInformation {
  final String deviceId;
  final String model;
  final String osVersion;

  DeviceInformation({
    required this.deviceId,
    required this.model,
    required this.osVersion,
  });

  @override
  String toString() => '$model ($osVersion) [$deviceId]';
}

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _webDeviceIdKey = 'secure_lms_web_device_id';

  static Future<DeviceInformation> getDeviceDetails() async {
    try {
      if (kIsWeb) {
        String? storedId = await _storage.read(key: _webDeviceIdKey);
        if (storedId == null || storedId.isEmpty) {
          storedId = 'WEB-${const Uuid().v4()}';
          await _storage.write(key: _webDeviceIdKey, value: storedId);
        }
        return DeviceInformation(
          deviceId: storedId,
          model: 'Web Browser Container',
          osVersion: 'Web / HTML5 Engine',
        );
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return DeviceInformation(
          deviceId: androidInfo.id,
          model: '${androidInfo.manufacturer} ${androidInfo.model}',
          osVersion: 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
        );
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return DeviceInformation(
          deviceId: iosInfo.identifierForVendor ?? 'IOS-UNKNOWN-ID',
          model: iosInfo.name ?? iosInfo.model,
          osVersion: 'iOS ${iosInfo.systemVersion}',
        );
      } else if (Platform.isWindows) {
        final WindowsDeviceInfo winInfo = await _deviceInfo.windowsInfo;
        return DeviceInformation(
          deviceId: winInfo.deviceId,
          model: winInfo.computerName,
          osVersion: 'Windows ${winInfo.majorVersion}.${winInfo.minorVersion}',
        );
      } else if (Platform.isMacOS) {
        final MacOsDeviceInfo macInfo = await _deviceInfo.macOsInfo;
        return DeviceInformation(
          deviceId: macInfo.systemGUID ?? 'MAC-UNKNOWN-ID',
          model: macInfo.model,
          osVersion: 'macOS ${macInfo.osRelease}',
        );
      }
    } catch (e) {
      debugPrint('DeviceService error: $e');
    }

    // Fallback ID
    String? fallbackId = await _storage.read(key: _webDeviceIdKey);
    if (fallbackId == null) {
      fallbackId = 'DEVICE-${const Uuid().v4()}';
      await _storage.write(key: _webDeviceIdKey, value: fallbackId);
    }
    return DeviceInformation(
      deviceId: fallbackId,
      model: 'Generic Platform Device',
      osVersion: 'Standard OS',
    );
  }
}
