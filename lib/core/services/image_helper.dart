import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageHelper {
  /// Renders an image whether it is a Base64 string, HTTP/HTTPS URL, or asset path.
  static Widget buildImage(
    String? source, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? fallback,
  }) {
    final defaultFallback = fallback ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF1E293B),
          child: const Icon(Icons.image_outlined, color: Colors.white38),
        );

    if (source == null || source.trim().isEmpty) {
      return defaultFallback;
    }

    final trimmed = source.trim();

    // 1. Check if source is a Base64 string (data:image/... or raw base64)
    if (trimmed.startsWith('data:image/') || _isBase64(trimmed)) {
      try {
        final cleanBase64 = trimmed.contains(',')
            ? trimmed.split(',').last.replaceAll(RegExp(r'\s+'), '')
            : trimmed;
        final Uint8List bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => defaultFallback,
        );
      } catch (e) {
        debugPrint('ImageHelper base64 decode error: $e');
        return defaultFallback;
      }
    }

    // 2. Check if source is HTTP/HTTPS URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => defaultFallback,
      );
    }

    // 3. Fallback asset or icon
    return defaultFallback;
  }

  /// Convert binary bytes to Base64 data URL string
  static String bytesToBase64DataUrl(Uint8List bytes, {String mimeType = 'image/png'}) {
    final base64String = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64String';
  }

  static bool _isBase64(String str) {
    if (str.length < 100) return false; // Base64 images are typically long strings
    final RegExp base64RegExp = RegExp(
      r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
    );
    final cleanStr = str.replaceAll(RegExp(r'\s+'), '');
    return base64RegExp.hasMatch(cleanStr);
  }
}
