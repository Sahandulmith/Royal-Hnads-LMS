import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../core/services/lms_repository.dart';
import '../../core/services/security_service.dart';
import '../../models/video.dart';
import '../../models/user_video_permission.dart';
import '../widgets/web_youtube_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  InAppWebViewController? _mobileWebViewController;
  UserVideoPermission? _permission;
  bool _isLoadingPermission = true;
  bool _isLimitReached = false;
  bool _isScreenRecordingDetected = false;
  bool _isFullScreen = false;
  bool _isFitOriginal = true;

  // Timers
  late DateTime _sessionStartTime;
  int _totalWatchedSeconds = 0;
  Timer? _sessionWatchTimer;
  Timer? _screenRecordingCheckTimer;
  bool _hasLoggedCompletion = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _hasSyncedDuration = false;
  bool _hasPlayerError = false;
  int _playerErrorCode = 0;

  // Current position state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _totalDuration = Duration(seconds: widget.video.durationSeconds);
    _enableAntiScreenRecord();
    _checkPermissionAndInitPlayer();
  }

  Future<void> _enableAntiScreenRecord() async {
    if (kIsWeb) return;

    // Periodically check if a screen recording app is actively running
    _screenRecordingCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      final isRecording = await SecurityService.isScreenRecordingActive();
      if (isRecording != _isScreenRecordingDetected && mounted) {
        setState(() {
          _isScreenRecordingDetected = isRecording;
        });
        if (isRecording && _mobileWebViewController != null) {
          _mobileWebViewController
              ?.evaluateJavascript(source: 'pauseVideo();');
        }
      }
    });
  }

  Future<void> _checkPermissionAndInitPlayer() async {
    final repo = Provider.of<LmsRepository>(context, listen: false);
    final student = repo.currentUser;

    if (student == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Admins bypass view limits
    if (student.isAdmin) {
      _initSessionWatchTimer();
      if (mounted) {
        setState(() => _isLoadingPermission = false);
      }
      return;
    }

    final perm = repo.getPermissionForStudent(student.uid, widget.video.id);

    if (perm.isLimitReached) {
      if (mounted) {
        setState(() {
          _permission = perm;
          _isLimitReached = true;
          _isLoadingPermission = false;
        });
      }
      return;
    }

    // Student has available views -> Consume 1 view for this session
    await repo.incrementUsedViews(
      studentId: student.uid,
      videoId: widget.video.id,
    );

    // Fetch updated permission object
    final updatedPerm = repo.getPermissionForStudent(student.uid, widget.video.id);

    if (mounted) {
      setState(() {
        _permission = updatedPerm;
        _isLimitReached = false;
        _isLoadingPermission = false;
      });
    }

    _initSessionWatchTimer();
  }

  void _initSessionWatchTimer() {
    // Watch duration timer & smooth position ticker
    _sessionWatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if ((_isPlaying || kIsWeb) && !_isScreenRecordingDetected) {
        _totalWatchedSeconds++;

        // Smoothly advance Flutter UI position timer every second when video is playing
        if (_isPlaying) {
          setState(() {
            final nextSec = _currentPosition.inSeconds + 1;
            final maxSec = _totalDuration.inSeconds > 0
                ? _totalDuration.inSeconds
                : 999999;
            _currentPosition = Duration(seconds: nextSec.clamp(0, maxSec));
          });
        }
      }
    });

    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _mobileWebViewController?.evaluateJavascript(source: 'pauseVideo();');
      setState(() => _isPlaying = false);
    } else {
      _mobileWebViewController?.evaluateJavascript(source: 'playVideo();');
      setState(() => _isPlaying = true);
    }
    _startHideControlsTimer();
  }

  void _seekBackward() {
    final maxSec =
        _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 999999;
    final targetSec = (_currentPosition.inSeconds - 10).clamp(0, maxSec);
    _mobileWebViewController?.evaluateJavascript(source: 'seekTo($targetSec);');
    setState(() {
      _currentPosition = Duration(seconds: targetSec);
    });
    _startHideControlsTimer();
  }

  void _seekForward() {
    final maxSec =
        _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 999999;
    final targetSec = (_currentPosition.inSeconds + 10).clamp(0, maxSec);
    _mobileWebViewController?.evaluateJavascript(source: 'seekTo($targetSec);');
    setState(() {
      _currentPosition = Duration(seconds: targetSec);
    });
    _startHideControlsTimer();
  }

  void _onSliderChanged(double val) {
    final targetSec = val.toInt();
    _mobileWebViewController?.evaluateJavascript(source: 'seekTo($targetSec);');
    setState(() {
      _currentPosition = Duration(seconds: targetSec);
    });
    _startHideControlsTimer();
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
  }

  Future<void> _recordWatchSession({required bool isCompleted}) async {
    final repo = Provider.of<LmsRepository>(context, listen: false);
    final endTime = DateTime.now();

    await repo.recordWatchSession(
      video: widget.video,
      startTime: _sessionStartTime,
      endTime: endTime,
      watchDurationSeconds: _totalWatchedSeconds,
      isCompleted: isCompleted,
    );
  }

  @override
  void dispose() {
    _sessionWatchTimer?.cancel();
    _screenRecordingCheckTimer?.cancel();
    _hideControlsTimer?.cancel();

    if (!_hasLoggedCompletion && !_isLimitReached) {
      _recordWatchSession(isCompleted: false);
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoadingPermission
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : _isScreenRecordingDetected
                ? _buildScreenRecordingDetectedView()
                : _isLimitReached
                    ? _buildLimitReachedView()
                    : _hasPlayerError
                        ? _buildPlayerErrorView()
                        : _buildPlayerView(),
      ),
    );
  }

  bool get _isEmbedError =>
      _playerErrorCode == 150 ||
      _playerErrorCode == 101 ||
      _playerErrorCode == 152;

  // --- YOUTUBE ERROR VIEW ---
  Widget _buildPlayerErrorView() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.redAccent.withAlpha(120), width: 2),
                ),
                child: const Icon(Icons.play_circle_outline_rounded,
                    size: 56, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'Video Cannot Be Played',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isEmbedError
                    ? 'The owner of this video has restricted playback in embedded players.\n\nPlease ask your administrator to upload this video to a YouTube account with embedding enabled.'
                    : 'This video could not be loaded. It may have been removed or is restricted.\n\nError Code: $_playerErrorCode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (_isEmbedError)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amberAccent.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.amberAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To fix: Go to YouTube Studio → Video → Details → Enable "Allow embedding"',
                          style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                label: const Text('Go Back',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SCREEN RECORDING DETECTED VIEW ---
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
              child: const Icon(Icons.videocam_off_rounded,
                  size: 60, color: Colors.redAccent),
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
              'Screen recording software detected. Video playback is paused to protect copyright content.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Exit Video Player',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LIMIT REACHED VIEW ---
  Widget _buildLimitReachedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.redAccent.withAlpha(100), width: 2),
              ),
              child: const Icon(Icons.lock_clock_rounded,
                  size: 56, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              'Viewing Limit Exceeded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have reached the maximum allowed watch limit (${_permission?.allowedViews ?? 1} view) for this lesson.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Back to Lessons',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MAIN PLAYER VIEW ---
  Widget _buildPlayerView() {
    return GestureDetector(
      onTap: kIsWeb ? null : _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 1. Video Player Viewport
          if (kIsWeb)
            Positioned.fill(
              child: getWebYoutubePlayer(widget.video.youtubeId,
                  fitOriginal: _isFitOriginal),
            )
          else
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: MobileYoutubePlayer(
                  youtubeId: widget.video.youtubeId,
                  fitOriginal: _isFitOriginal,
                  onCreated: (controller) {
                    _mobileWebViewController = controller;
                  },
                  onStateUpdate: (state, currentTime, duration) {
                    if (!mounted || _isLimitReached) return;

                    final isPlaying = (state == 1);
                    final pos = Duration(seconds: currentTime.toInt());
                    final dur = duration > 0
                        ? Duration(seconds: duration.toInt())
                        : Duration(seconds: widget.video.durationSeconds);

                    setState(() {
                      _isPlaying = isPlaying;
                      if ((pos.inSeconds - _currentPosition.inSeconds).abs() > 2 ||
                          _currentPosition == Duration.zero) {
                        _currentPosition = pos;
                      }
                      if (dur.inSeconds > 0) {
                        _totalDuration = dur;
                      }
                    });

                    // Auto-sync actual video duration to Firestore
                    if (!_hasSyncedDuration && duration > 0) {
                      final storedDuration = widget.video.durationSeconds;
                      final actualDuration = duration.toInt();
                      if (storedDuration == 0 ||
                          (actualDuration - storedDuration).abs() > 10) {
                        _hasSyncedDuration = true;
                        FirebaseFirestore.instance
                            .collection('videos')
                            .doc(widget.video.id)
                            .update({'duration_seconds': actualDuration}).catchError(
                          (e) => debugPrint('Duration sync error: $e'),
                        );
                      } else {
                        _hasSyncedDuration = true;
                      }
                    }

                    // Completion check (>80% or ended)
                    if ((state == 0 ||
                            (_totalDuration.inSeconds > 0 &&
                                pos.inSeconds >=
                                    (_totalDuration.inSeconds * 0.85))) &&
                        !_hasLoggedCompletion) {
                      _hasLoggedCompletion = true;
                      _recordWatchSession(isCompleted: true);
                    }
                  },
                  onError: (code) {
                    if (!mounted) return;
                    setState(() {
                      _hasPlayerError = true;
                      _playerErrorCode = code;
                    });
                  },
                ),
              ),
            ),

          // 2. Dynamic Anti-Piracy Watermark
          _buildDynamicWatermark(),

          // 3. WEB Header (Unchanged)
          if (kIsWeb)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Row(
                            children: [
                              Icon(Icons.shield_sharp,
                                  color: Color(0xFF10B981), size: 11),
                              SizedBox(width: 4),
                              Text(
                                'Protected Stream • Click video to pause/play',
                                style: TextStyle(
                                    color: Color(0xFF10B981), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_permission != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6366F1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined,
                                color: Colors.indigoAccent, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              '${_permission!.remainingViews} View Remaining',
                              style: const TextStyle(
                                color: Colors.indigoAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(
                        _isFitOriginal
                            ? Icons.aspect_ratio_rounded
                            : Icons.fit_screen_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _isFitOriginal = !_isFitOriginal);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isFitOriginal
                                  ? 'Video Mode: Original Size (Fit)'
                                  : 'Video Mode: Zoom Fill',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      tooltip: _isFitOriginal
                          ? 'Switch to Zoom Fill'
                          : 'Switch to Original Size (Fit)',
                    ),
                  ],
                ),
              ),
            ),

          // 4. MOBILE Custom Controls Overlay
          if (!kIsWeb && _showControls)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black.withAlpha(160),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar (Back button, Title, Views Remaining, Fullscreen)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  children: [
                                    Icon(Icons.shield_sharp,
                                        color: Color(0xFF10B981), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Protected Stream • Anti-Screen Recording Active',
                                      style: TextStyle(
                                          color: Color(0xFF10B981), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_permission != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF6366F1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.remove_red_eye_outlined,
                                      color: Colors.indigoAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_permission!.remainingViews} View Remaining',
                                    style: const TextStyle(
                                      color: Colors.indigoAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              _isFitOriginal
                                  ? Icons.aspect_ratio_rounded
                                  : Icons.fit_screen_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              setState(() => _isFitOriginal = !_isFitOriginal);
                              _startHideControlsTimer();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isFitOriginal
                                        ? 'Video Mode: Original Size (Fit)'
                                        : 'Video Mode: Zoom Fill',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            tooltip: _isFitOriginal
                                ? 'Switch to Zoom Fill'
                                : 'Switch to Original Size (Fit)',
                          ),
                          IconButton(
                            icon: Icon(
                              _isFullScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: _toggleFullScreen,
                            tooltip: _isFullScreen
                                ? 'Exit Fullscreen'
                                : 'Fullscreen Rotation',
                          ),
                        ],
                      ),
                    ),

                    // Center Transport Controls (Rewind 10s, Play/Pause circle, Forward 10s)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.replay_10_rounded,
                              color: Colors.white),
                          onPressed: _seekBackward,
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.forward_10_rounded,
                              color: Colors.white),
                          onPressed: _seekForward,
                        ),
                      ],
                    ),

                    // Bottom Bar (Progress slider & Timestamps)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_currentPosition),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: Slider(
                              value: _currentPosition.inSeconds
                                  .toDouble()
                                  .clamp(
                                    0.0,
                                    _totalDuration.inSeconds > 0
                                        ? _totalDuration.inSeconds.toDouble()
                                        : 1.0,
                                  ),
                              min: 0.0,
                              max: _totalDuration.inSeconds > 0
                                  ? _totalDuration.inSeconds.toDouble()
                                  : 1.0,
                              activeColor: const Color(0xFF6366F1),
                              inactiveColor: Colors.white24,
                              onChanged: _onSliderChanged,
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicWatermark() {
    final repo = Provider.of<LmsRepository>(context, listen: false);
    final email = repo.currentUser?.email ?? 'Protected Account';
    final name = repo.currentUser?.name ?? 'Royal LMS';

    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.22,
          child: Transform.rotate(
            angle: -0.15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                'PROHIBITED RECORDING • $name ($email)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileYoutubePlayer extends StatefulWidget {
  final String youtubeId;
  final bool fitOriginal;
  final Function(InAppWebViewController controller)? onCreated;
  final Function(int state, double currentTime, double duration)?
      onStateUpdate;
  final Function(int errorCode)? onError;

  const MobileYoutubePlayer({
    super.key,
    required this.youtubeId,
    this.fitOriginal = true,
    this.onCreated,
    this.onStateUpdate,
    this.onError,
  });

  @override
  State<MobileYoutubePlayer> createState() => _MobileYoutubePlayerState();
}

class _MobileYoutubePlayerState extends State<MobileYoutubePlayer> {
  @override
  Widget build(BuildContext context) {
    // Shields no longer needed on Mobile because we inject CSS directly into YouTube iframe
    final shieldHeight = 0.0;

    const injectJs = '''
(function() {
  // Always define global player control functions on window
  window.playVideo = function() {
    try {
      var mp = document.getElementById('movie_player');
      if (mp && typeof mp.playVideo === 'function') {
        mp.playVideo();
        return;
      }
    } catch(e) {}
    try {
      var v = document.querySelector('video');
      if (v) { v.play(); }
    } catch(e) {}
  };

  window.pauseVideo = function() {
    try {
      var mp = document.getElementById('movie_player');
      if (mp && typeof mp.pauseVideo === 'function') {
        mp.pauseVideo();
        return;
      }
    } catch(e) {}
    try {
      var v = document.querySelector('video');
      if (v) { v.pause(); }
    } catch(e) {}
  };

  window.seekTo = function(seconds) {
    try {
      var mp = document.getElementById('movie_player');
      if (mp && typeof mp.seekTo === 'function') {
        mp.seekTo(seconds, true);
        return;
      }
    } catch(e) {}
    try {
      var v = document.querySelector('video');
      if (v) { v.currentTime = seconds; }
    } catch(e) {}
  };

  // CSS hiding of YouTube native top title, channel name, copy link, watermark
  function applyStrictStyles() {
    var styleId = 'lms-strict-youtube-hide-style';
    var style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      style.innerHTML = `
        .ytp-chrome-top,
        .ytp-chrome-top-buttons,
        .ytp-title,
        .ytp-title-link,
        .ytp-title-channel,
        .ytp-title-text,
        .ytp-copylink-button,
        .ytp-watermark,
        .ytp-youtube-button,
        .ytp-pause-overlay,
        .ytp-pause-overlay-container,
        .ytp-gradient-top,
        .ytp-gradient-bottom,
        .ytp-show-cards-title,
        .ytp-ce-element,
        .ytp-cards-button,
        .ytp-impression-link,
        .ytp-error,
        .ytp-paid-content-overlay,
        .ytp-unmute,
        .ytp-cbox,
        .ytp-contextmenu,
        .ytp-share-panel,
        a.ytp-title-link,
        div.ytp-chrome-top {
          display: none !important;
          opacity: 0 !important;
          visibility: hidden !important;
          pointer-events: none !important;
          height: 0px !important;
          width: 0px !important;
          max-height: 0px !important;
          max-width: 0px !important;
          overflow: hidden !important;
          transform: scale(0) !important;
        }
      `;
      (document.head || document.documentElement).appendChild(style);
    }

    var hideSelectors = [
      '.ytp-chrome-top', '.ytp-title', '.ytp-title-link', '.ytp-title-channel',
      '.ytp-title-text', '.ytp-watermark', '.ytp-youtube-button', '.ytp-pause-overlay',
      '.ytp-gradient-top', '.ytp-gradient-bottom', '.ytp-copylink-button', '.ytp-ce-element',
      '.ytp-chrome-top-buttons', '.ytp-show-cards-title'
    ];
    for (var s = 0; s < hideSelectors.length; s++) {
      var els = document.querySelectorAll(hideSelectors[s]);
      for (var i = 0; i < els.length; i++) {
        try {
          els[i].style.setProperty('display', 'none', 'important');
          els[i].style.setProperty('opacity', '0', 'important');
          els[i].style.setProperty('visibility', 'hidden', 'important');
          els[i].style.setProperty('pointer-events', 'none', 'important');
        } catch(e) {}
      }
    }
  }

  applyStrictStyles();

  if (!window._lmsTimerStarted) {
    window._lmsTimerStarted = true;
    setInterval(applyStrictStyles, 150);

    try {
      var observer = new MutationObserver(function() {
        applyStrictStyles();
      });
      if (document.body) {
        observer.observe(document.body, { childList: true, subtree: true });
      } else if (document.documentElement) {
        observer.observe(document.documentElement, { childList: true, subtree: true });
      }
    } catch(e) {}

    function sendUpdate() {
      var currentTime = 0;
      var duration = 0;
      var state = -1;

      try {
        var mp = document.getElementById('movie_player');
        if (mp && typeof mp.getCurrentTime === 'function') {
          currentTime = mp.getCurrentTime() || 0;
          duration = mp.getDuration() || 0;
          var mpState = mp.getPlayerState();
          state = (mpState === 0) ? 0 : ((mpState === 1) ? 1 : 2);
        }
      } catch(e) {}

      if (currentTime === 0 && duration === 0) {
        try {
          var v = document.querySelector('video');
          if (v) {
            currentTime = v.currentTime || 0;
            duration = v.duration || 0;
            state = v.ended ? 0 : (v.paused ? 2 : 1);
          }
        } catch(e) {}
      }

      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        try {
          window.flutter_inappwebview.callHandler('onPlayerStateUpdate', {
            'state': state,
            'currentTime': currentTime,
            'duration': duration
          });
        } catch(e) {}
      }
    }

    setInterval(sendUpdate, 250);

    setTimeout(function() {
      window.playVideo();
    }, 600);
  }
})();
''';

    final embedUrl = 'https://www.youtube-nocookie.com/embed/${widget.youtubeId}'
        '?autoplay=1&controls=0&rel=0&modestbranding=1'
        '&enablejsapi=1&disablekb=1&fs=0&iv_load_policy=3'
        '&playsinline=1&color=white';

    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(embedUrl),
              headers: {
                'Referer': 'https://royalhand.netlify.app/',
              },
            ),
            initialUserScripts: UnmodifiableListView([
              UserScript(
                source: injectJs,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: false,
              transparentBackground: true,
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (controller) {
              widget.onCreated?.call(controller);

              controller.addJavaScriptHandler(
                handlerName: 'onPlayerStateUpdate',
                callback: (args) {
                  if (args.isNotEmpty && args[0] is Map) {
                    final data = args[0] as Map;
                    final state = (data['state'] as num?)?.toInt() ?? -1;
                    final currentTime =
                        (data['currentTime'] as num?)?.toDouble() ?? 0.0;
                    final duration =
                        (data['duration'] as num?)?.toDouble() ?? 0.0;
                    widget.onStateUpdate?.call(state, currentTime, duration);
                  }
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'onPlayerError',
                callback: (args) {
                  if (args.isNotEmpty) {
                    final code = (args[0] as num?)?.toInt() ?? 0;
                    widget.onError?.call(code);
                  }
                },
              );
            },
            onLoadStop: (controller, url) {
              controller.evaluateJavascript(source: injectJs);
            },
          ),
        ),
      ],
    );
  }
}
