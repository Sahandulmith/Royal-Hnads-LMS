import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/services/lms_repository.dart';
import '../../core/services/security_service.dart';
import '../../models/live_class.dart';

class LiveClassPlayerScreen extends StatefulWidget {
  final LiveClass liveClass;

  const LiveClassPlayerScreen({super.key, required this.liveClass});

  @override
  State<LiveClassPlayerScreen> createState() => _LiveClassPlayerScreenState();
}

class _LiveClassPlayerScreenState extends State<LiveClassPlayerScreen> {
  String _getSecurityHideScript(String studentName) {
    final sanitizedName = studentName.replaceAll("'", "\\'").replaceAll('"', '\\"');
    return '''
(function() {
  var targetStudentName = "$sanitizedName";
  
  var css = `
    .meeting-info-icon,
    .meeting-info-button,
    .meeting-summary-icon,
    .meeting-info-dialog,
    .meeting-info-popover,
    .meeting-info-modal,
    .meeting-client-info,
    .meeting-info-content,
    .sharer-info-dialog,
    .action-sheet,
    .zm-modal-dialog,
    .zm-modal,
    .zm-popover,
    .zoom-modal,
    .zm-logo,
    .zm-header-logo,
    .copy-link-button,
    .copy-meeting-link,
    .security-option,
    .meeting-detail,
    .info-modal,
    .meeting-summary,
    div[class*="action-sheet"],
    div[class*="meeting-info"],
    div[class*="meeting-detail"],
    div[class*="info-modal"],
    div[class*="meeting-summary"],
    div[class*="security"],
    button[class*="shield"],
    button[class*="meeting-info"],
    button[aria-label="Meeting Information"],
    button[aria-label="Meeting info"],
    button[aria-label="Meeting Info"],
    button[aria-label="Security"],
    button[aria-label*="Copy" i],
    button[aria-label*="info" i],
    button[aria-label*="detail" i] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }

    .header-title,
    .meeting-title,
    .header-main-title,
    div[class*="header-title"],
    div[class*="meeting-title"] {
        pointer-events: none !important;
    }
  `;

  function applySecurityAndAutoJoin() {
    try {
      if (!document.getElementById('hide-zoom-info-style')) {
        var style = document.createElement('style');
        style.id = 'hide-zoom-info-style';
        style.type = 'text/css';
        style.appendChild(document.createTextNode(css));
        (document.head || document.documentElement).appendChild(style);
      }

      var elements = document.querySelectorAll('div, section, article, main, aside, [role="dialog"], [role="region"]');
      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var text = (el.innerText || el.textContent || '');
        if (text.indexOf('Invite Link') !== -1 || 
            text.indexOf('Meeting ID') !== -1 || 
            text.indexOf('Passcode') !== -1 || 
            text.indexOf('Participant ID') !== -1 || 
            text.indexOf('Copy meeting link') !== -1 ||
            text.indexOf('zoom.us') !== -1 ||
            text.indexOf('Host:') !== -1 ||
            text.indexOf('Host ') !== -1 ||
            text.indexOf('Personal Meeting Room') !== -1) {
          if (el.offsetHeight > 0 && el.offsetHeight < window.innerHeight * 0.95) {
            el.style.setProperty('display', 'none', 'important');
            el.style.setProperty('visibility', 'hidden', 'important');
            el.style.setProperty('opacity', '0', 'important');
            el.style.setProperty('pointer-events', 'none', 'important');
          }
        }
      }

      var nameInput = document.querySelector('input[name="inputname"], input[id="inputname"], input[placeholder*="Name" i], .input-name');
      if (nameInput) {
        if (nameInput.value !== targetStudentName) {
          try {
            var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
            if (nativeSetter) {
              nativeSetter.call(nameInput, targetStudentName);
            } else {
              nameInput.value = targetStudentName;
            }
          } catch(err) {
            nameInput.value = targetStudentName;
          }
          nameInput.dispatchEvent(new Event('input', { bubbles: true }));
          nameInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
        nameInput.readOnly = true;
      }

      if (!window._hasClickedJoin) {
        var joinCandidates = document.querySelectorAll('button, input[type="button"], input[type="submit"], div[role="button"], a[role="button"], .preview-join-button');
        for (var j = 0; j < joinCandidates.length; j++) {
          var btn = joinCandidates[j];
          var btnText = (btn.innerText || btn.textContent || btn.value || '').trim().toLowerCase();
          var btnClass = (btn.className || '').toString().toLowerCase();

          var isJoinBtn = (btnText === 'join' || 
                           btnText === 'join meeting' || 
                           btnText === 'enter' || 
                           btnClass.indexOf('preview-join-button') !== -1 || 
                           (btnText.indexOf('join') !== -1 && btnText.indexOf('audio') === -1));

          if (isJoinBtn && !btn.disabled) {
            if (nameInput && nameInput.value !== targetStudentName) {
              try {
                var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                if (nativeSetter) { nativeSetter.call(nameInput, targetStudentName); } else { nameInput.value = targetStudentName; }
              } catch(e) { nameInput.value = targetStudentName; }
              nameInput.dispatchEvent(new Event('input', { bubbles: true }));
              nameInput.dispatchEvent(new Event('change', { bubbles: true }));
            }

            window._hasClickedJoin = true;
            try { btn.click(); } catch(e) {}
            try {
              btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
            } catch(e) {}
            break;
          }
        }
      }

      if (!window._hasClickedAllow) {
        var allowBtns = document.querySelectorAll('button, div[role="button"], a');
        for (var a = 0; a < allowBtns.length; a++) {
          var ab = allowBtns[a];
          var abText = (ab.innerText || ab.textContent || '').trim().toLowerCase();
          if (abText === 'allow' || abText === 'got it' || abText === 'ok' || abText === 'agree' || abText === 'allow access') {
            window._hasClickedAllow = true;
            try { ab.click(); } catch(e) {}
            try {
              ab.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
            } catch(e) {}
            break;
          }
        }
      }

      if (!window._hasClickedAudio) {
        var audioBtns = document.querySelectorAll('button, div[role="button"]');
        for (var k = 0; k < audioBtns.length; k++) {
          var abtn = audioBtns[k];
          var atext = (abtn.innerText || abtn.textContent || '').trim().toLowerCase();
          if (atext.indexOf('join with computer audio') !== -1 || 
              atext.indexOf('computer audio') !== -1 || 
              atext.indexOf('wifi or cellular data') !== -1 || 
              atext.indexOf('call via device audio') !== -1 || 
              atext === 'join audio') {
            if (!abtn.disabled) {
              window._hasClickedAudio = true;
              try { abtn.click(); } catch(e) {}
              try {
                abtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
              } catch(e) {}
              break;
            }
          }
        }
      }
    } catch(e) {}
  }

  applySecurityAndAutoJoin();
  if (!window._zoomHideInterval) {
    window._zoomHideInterval = setInterval(applySecurityAndAutoJoin, 400);
  }
})();
''';
  }

  YoutubePlayerController? _youtubeController;
  InAppWebViewController? _webViewController;

  bool _isYouTubeStream = false;
  bool _isScreenRecordingDetected = false;
  bool _isFullScreen = false;
  bool _isLoading = true;

  Timer? _screenRecordingCheckTimer;

  @override
  void initState() {
    super.initState();
    _requestMediaPermissions();
    _enableSecurity();
    _initStreamPlayer();
  }

  Future<void> _requestMediaPermissions() async {
    try {
      await [
        Permission.microphone,
        Permission.camera,
      ].request();
    } catch (e) {
      debugPrint('Media permission request error: $e');
    }
  }

  Future<void> _enableSecurity() async {
    await SecurityService.enableSecureScreen();

    // Check periodically if screen recording software is active
    _screenRecordingCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final isRecording = await SecurityService.isScreenRecordingActive();
      if (isRecording != _isScreenRecordingDetected && mounted) {
        setState(() {
          _isScreenRecordingDetected = isRecording;
        });

        if (isRecording) {
          _youtubeController?.pause();
        }
      }
    });
  }

  void _initStreamPlayer() {
    final url = widget.liveClass.classUrl.trim();
    final isYt = widget.liveClass.platform == 'youtube' ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');

    if (isYt) {
      final ytId = YoutubePlayer.convertUrlToId(url);
      if (ytId != null && ytId.isNotEmpty) {
        _isYouTubeStream = true;
        _youtubeController = YoutubePlayerController(
          initialVideoId: ytId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            isLive: true,
            mute: false,
            disableDragSeek: true,
            hideControls: false,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    // Default to InAppWebView for Zoom join web links or web live links
    _isYouTubeStream = false;
    setState(() => _isLoading = false);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    Future.delayed(const Duration(milliseconds: 350), () {
      _webViewController?.evaluateJavascript(source: 'window.dispatchEvent(new Event("resize"));');
    });
  }

  @override
  void dispose() {
    _screenRecordingCheckTimer?.cancel();
    _youtubeController?.dispose();

    // Reset screen orientation & UI overlay mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SecurityService.disableSecureScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context, listen: false);
    final studentName = repo.currentUser?.name ?? 'Student';
    final hideScript = _getSecurityHideScript(studentName);

    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !_isFullScreen,
          bottom: !_isFullScreen,
          left: false,
          right: false,
          child: _isScreenRecordingDetected
              ? _buildScreenRecordingDetectedView()
              : Column(
                  children: [
                    // Top App Bar (Hidden in Fullscreen)
                    if (!_isFullScreen) _buildHeaderBar(),

                    // Main Stream Viewport
                    Expanded(
                      child: Stack(
                        children: [
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                            )
                          else if (_isYouTubeStream && _youtubeController != null)
                            Center(
                              child: YoutubePlayer(
                                controller: _youtubeController!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: const Color(0xFF6366F1),
                              ),
                            )
                          else
                            InAppWebView(
                              initialUrlRequest: URLRequest(
                                url: WebUri(_formatZoomOrWebUrl(widget.liveClass.classUrl, studentName)),
                              ),
                              initialUserScripts: UnmodifiableListView<UserScript>([
                                UserScript(
                                  source: hideScript,
                                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                                ),
                                UserScript(
                                  source: hideScript,
                                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                                ),
                              ]),
                              initialSettings: InAppWebViewSettings(
                                javaScriptEnabled: true,
                                mediaPlaybackRequiresUserGesture: false,
                                allowsInlineMediaPlayback: true,
                                useShouldOverrideUrlLoading: false,
                                transparentBackground: true,
                                useHybridComposition: true,
                              ),
                              onWebViewCreated: (controller) {
                                _webViewController = controller;
                              },
                              onLoadStop: (controller, url) {
                                controller.evaluateJavascript(source: hideScript);
                              },
                              onProgressChanged: (controller, progress) {
                                if (progress > 30) {
                                  controller.evaluateJavascript(source: hideScript);
                                }
                              },
                              onUpdateVisitedHistory: (controller, url, isReload) {
                                controller.evaluateJavascript(source: hideScript);
                              },
                              onPermissionRequest: (controller, request) async {
                                return PermissionResponse(
                                  resources: request.resources,
                                  action: PermissionResponseAction.GRANT,
                                );
                              },
                            ),

                          // Floating Controls (Fullscreen Toggle & Security Badge)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(180),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isFullScreen
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    onPressed: _toggleFullScreen,
                                    tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Fullscreen Rotation',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
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

    if (studentName.isNotEmpty) {
      final encodedName = Uri.encodeComponent(studentName);
      final separator = clean.contains('?') ? '&' : '?';
      if (!clean.contains('dn=')) {
        clean = '$clean${separator}dn=$encodedName';
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

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE • ${widget.liveClass.platform.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.liveClass.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_sharp, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 4),
                Text(
                  'Protected Live Stream',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _toggleFullScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenRecordingDetectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent, width: 2.5),
              ),
              child: const Icon(Icons.videocam_off_rounded, size: 60, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              'Screen Recording Blocked!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Screen recording or capture software has been detected. Live classroom stream is paused to protect copyright content.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Exit Live Classroom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
