import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class YouTubeService {
  /// Extracts a clean YouTube video ID from any YouTube URL format or plain ID.
  static String extractVideoId(String input) {
    input = input.trim();
    if (input.contains('v=')) {
      return input.split('v=').last.split('&').first.trim();
    } else if (input.contains('youtu.be/')) {
      return input.split('youtu.be/').last.split('?').first.trim();
    } else if (input.contains('youtube.com/shorts/')) {
      return input.split('youtube.com/shorts/').last.split('?').first.trim();
    }
    // Clean trailing paths/params and return as-is (plain video ID)
    return input.split('/').last.split('?').first.trim();
  }

  /// Fetches the real video duration in seconds by parsing the YouTube page.
  /// No API key required. Returns 0 on failure or when running on web (CORS).
  static Future<int> fetchVideoDuration(String videoId) async {
    if (videoId.isEmpty) return 0;
    // Web platform cannot call YouTube due to CORS restrictions
    if (kIsWeb) return 0;

    try {
      final url = 'https://www.youtube.com/watch?v=$videoId';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              'Accept-Language': 'en-US,en;q=0.9',
              'Accept': 'text/html',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        // Primary: "lengthSeconds":"XXXXX" embedded in ytInitialData
        final regex1 = RegExp(r'"lengthSeconds":"(\d+)"');
        final match1 = regex1.firstMatch(response.body);
        if (match1 != null) {
          final seconds = int.tryParse(match1.group(1) ?? '0') ?? 0;
          if (seconds > 0) {
            debugPrint(
                'YouTubeService: Fetched $seconds s for video $videoId');
            return seconds;
          }
        }
        // Fallback: "approxDurationMs":"XXXXX"
        final regex2 = RegExp(r'"approxDurationMs":"(\d+)"');
        final match2 = regex2.firstMatch(response.body);
        if (match2 != null) {
          final ms = int.tryParse(match2.group(1) ?? '0') ?? 0;
          if (ms > 0) return ms ~/ 1000;
        }
      }
    } catch (e) {
      debugPrint('YouTubeService.fetchVideoDuration error: $e');
    }
    return 0;
  }

  /// Parses a human-readable duration string ("M:SS" or "H:MM:SS") into seconds.
  /// Returns 0 if the format is invalid.
  static int parseDurationString(String input) {
    input = input.trim();
    final parts =
        input.split(':').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    if (parts.length == 2) {
      return parts[0] * 60 + parts[1]; // M:SS
    } else if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2]; // H:MM:SS
    } else if (parts.length == 1 && parts[0] > 0) {
      return parts[0]; // Plain seconds
    }
    return 0;
  }

  /// Formats seconds into "MM:SS" or "H:MM:SS" string.
  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
}
