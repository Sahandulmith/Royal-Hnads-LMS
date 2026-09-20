import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Base64ImageCache {
  static final Map<String, MemoryImage> _imageMap = {};
  static final Map<String, Uint8List> _bytesMap = {};

  static MemoryImage? getMemoryImage(String? base64Raw) {
    if (base64Raw == null || base64Raw.trim().isEmpty) return null;
    final clean = base64Raw.contains(',') ? base64Raw.split(',').last.trim() : base64Raw.trim();
    if (clean.isEmpty) return null;

    if (_imageMap.containsKey(clean)) {
      return _imageMap[clean];
    }

    try {
      final bytes = base64Decode(clean);
      final memoryImage = MemoryImage(bytes);
      _imageMap[clean] = memoryImage;
      _bytesMap[clean] = bytes;
      return memoryImage;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? getBytes(String? base64Raw) {
    if (base64Raw == null || base64Raw.trim().isEmpty) return null;
    final clean = base64Raw.contains(',') ? base64Raw.split(',').last.trim() : base64Raw.trim();
    if (clean.isEmpty) return null;

    if (_bytesMap.containsKey(clean)) {
      return _bytesMap[clean];
    }

    try {
      final bytes = base64Decode(clean);
      final memoryImage = MemoryImage(bytes);
      _imageMap[clean] = memoryImage;
      _bytesMap[clean] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    _imageMap.clear();
    _bytesMap.clear();
  }
}

class UserAvatar extends StatelessWidget {
  final String? profileImageBase64;
  final String name;
  final double radius;
  final VoidCallback? onTap;
  final bool enablePreview;

  const UserAvatar({
    super.key,
    required this.profileImageBase64,
    required this.name,
    this.radius = 20,
    this.onTap,
    this.enablePreview = true,
  });

  @override
  Widget build(BuildContext context) {
    final memoryImage = Base64ImageCache.getMemoryImage(profileImageBase64);
    final hasValidImage = memoryImage != null;

    Widget avatarWidget;
    if (hasValidImage) {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundImage: memoryImage,
      );
    } else {
      final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'U';
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF6366F1).withAlpha(40),
        child: Text(
          initial,
          style: TextStyle(
            color: const Color(0xFF6366F1),
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.9,
          ),
        ),
      );
    }

    final handleTap = onTap ??
        (enablePreview && hasValidImage
            ? () => showImagePreviewModal(context, profileImageBase64: profileImageBase64, name: name)
            : null);

    if (handleTap != null) {
      return GestureDetector(
        onTap: handleTap,
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }
}

void showImagePreviewModal(BuildContext context, {required String? profileImageBase64, required String name}) {
  if (profileImageBase64 == null || profileImageBase64.trim().isEmpty) return;

  final bytes = Base64ImageCache.getBytes(profileImageBase64);
  if (bytes == null) return;

  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.account_circle_rounded, color: Color(0xFF6366F1), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name\'s Profile Picture',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: 300,
                height: 300,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Error rendering image preview.', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

