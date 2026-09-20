import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

String? _extractYoutubeId(String url) {
  final clean = url.trim();
  if (clean.contains('youtu.be/')) {
    final segment = clean.split('youtu.be/').last;
    return segment.split('?').first.split('&').first;
  }
  if (clean.contains('youtube.com/watch')) {
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      return uri.queryParameters['v'];
    }
  }
  if (clean.contains('youtube.com/embed/')) {
    final segment = clean.split('youtube.com/embed/').last;
    return segment.split('?').first.split('&').first;
  }
  if (clean.contains('youtube.com/live/')) {
    final segment = clean.split('youtube.com/live/').last;
    return segment.split('?').first.split('&').first;
  }
  return null;
}

String _formatZoomOrWebUrl(String rawUrl, String studentName) {
  String clean = rawUrl.trim();
  if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
    clean = 'https://$clean';
  }
  if (clean.contains('zoom.us/j/')) {
    clean = clean.replaceAll('zoom.us/j/', 'zoom.us/wc/join/');
  } else if (clean.contains('zoom.us/s/')) {
    clean = clean.replaceAll('zoom.us/s/', 'zoom.us/wc/join/');
  }

  final separator = clean.contains('?') ? '&' : '?';

  // Force auto-connecting computer audio and microphone
  if (!clean.contains('autoJoinAudio=')) {
    clean = '$clean${separator}autoJoinAudio=1';
  }
  if (!clean.contains('preferAudio=')) {
    clean = '$clean&preferAudio=1';
  }
  if (!clean.contains('autojoin=')) {
    clean = '$clean&autojoin=1';
  }

  if (studentName.isNotEmpty) {
    final encodedName = Uri.encodeComponent(studentName);
    if (!clean.contains('dn=')) {
      clean = '$clean&dn=$encodedName';
    }
    if (!clean.contains('un=')) {
      clean = '$clean&un=$encodedName';
    }
    if (!clean.contains('uname=')) {
      clean = '$clean&uname=$encodedName';
    }
  }

  return clean;
}

Widget buildWebLivePlayer({
  required String url,
  required String platform,
  required String studentName,
}) {
  return WebLivePlayerWidget(
    url: url,
    platform: platform,
    studentName: studentName,
  );
}

class WebLivePlayerWidget extends StatefulWidget {
  final String url;
  final String platform;
  final String studentName;

  const WebLivePlayerWidget({
    super.key,
    required this.url,
    required this.platform,
    required this.studentName,
  });

  @override
  State<WebLivePlayerWidget> createState() => _WebLivePlayerWidgetState();
}

class _WebLivePlayerWidgetState extends State<WebLivePlayerWidget> {
  late String _cleanUrl;
  late bool _isYouTube;
  late String _formattedZoomUrl;
  String? _youtubeId;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _cleanUrl = widget.url.trim();
    _isYouTube = widget.platform.toLowerCase() == 'youtube' ||
        _cleanUrl.contains('youtube.com') ||
        _cleanUrl.contains('youtu.be');

    _formattedZoomUrl = _formatZoomOrWebUrl(_cleanUrl, widget.studentName);

    if (_isYouTube) {
      _youtubeId = _extractYoutubeId(_cleanUrl);
      final ytSrc = _youtubeId != null && _youtubeId!.isNotEmpty
          ? 'https://www.youtube-nocookie.com/embed/$_youtubeId?autoplay=1&live=1&modestbranding=1&playsinline=1'
          : _cleanUrl;

      _viewType = 'web-live-yt-${ytSrc.hashCode}';

      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewType!,
          (int viewId) {
            final iframe = html.IFrameElement()
              ..src = ytSrc
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..style.backgroundColor = '#000000'
              ..allow =
                  'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture'
              ..allowFullscreen = true;
            return iframe;
          },
        );
      } catch (_) {}
    } else {
      // Zoom or Web Stream
      _viewType = 'web-live-stream-${_formattedZoomUrl.hashCode}';

      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewType!,
          (int viewId) {
            final container = html.DivElement()
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.position = 'relative'
              ..style.backgroundColor = '#000000'
              ..style.overflow = 'hidden';

            final iframe = html.IFrameElement()
              ..src = _formattedZoomUrl
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..style.position = 'absolute'
              ..style.top = '0'
              ..style.left = '0'
              ..style.backgroundColor = '#000000'
              ..allow =
                  'camera *; microphone *; display-capture *; autoplay *; clipboard-write *; encrypted-media *; fullscreen *; geolocation *'
              ..allowFullscreen = true;

            // Top-Left Security Shield Overlay
            // Obscures and blocks clicking/hovering Zoom's (i) Meeting Information button
            // hiding Meeting ID, Passcode, Invite Link, and Host Name from students.
            final topLeftShield = html.DivElement()
              ..style.position = 'absolute'
              ..style.top = '0'
              ..style.left = '0'
              ..style.width = '380px'
              ..style.height = '48px'
              ..style.zIndex = '999'
              ..style.backgroundColor = '#000000'
              ..style.pointerEvents = 'auto';

            container.append(iframe);
            container.append(topLeftShield);

            return container;
          },
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewType == null) {
      return Container(color: Colors.black);
    }

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Render Embedded Live Class Viewport (IFrame + Security Shield)
          Positioned.fill(
            child: HtmlElementView(viewType: _viewType!),
          ),

          // Additional Security Shield overlay at top-left corner in Flutter tree
          // Prevents students from hovering or opening meeting info dialog
          if (!_isYouTube)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 380,
                height: 48,
                color: Colors.black,
              ),
            ),
        ],
      ),
    );
  }
}
