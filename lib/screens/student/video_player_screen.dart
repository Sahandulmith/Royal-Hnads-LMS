import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/services/lms_repository.dart';
import '../../core/services/security_service.dart';
import '../../models/video.dart';
import '../../models/user_video_permission.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _youtubeController;
  UserVideoPermission? _permission;
  bool _isLoadingPermission = true;
  bool _isLimitReached = false;
  bool _isScreenRecordingDetected = false;

  // Timers
  late DateTime _sessionStartTime;
  int _totalWatchedSeconds = 0;
  Timer? _sessionWatchTimer;
  Timer? _screenRecordingCheckTimer;
  bool _hasLoggedCompletion = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Current position state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _enableAntiScreenRecord();
    _checkPermissionAndInitPlayer();
  }

  Future<void> _enableAntiScreenRecord() async {
    await SecurityService.enableSecureScreen();

    // Periodically check if a screen recording app is actively running
    _screenRecordingCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final isRecording = await SecurityService.isScreenRecordingActive();
      if (isRecording != _isScreenRecordingDetected && mounted) {
        setState(() {
          _isScreenRecordingDetected = isRecording;
        });

        if (isRecording) {
          _youtubeController.pause();
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
      _initYoutubePlayer();
      setState(() => _isLoadingPermission = false);
      return;
    }

    final perm = repo.getPermissionForStudent(student.uid, widget.video.id);

    setState(() {
      _permission = perm;
      _isLimitReached = perm.isLimitReached;
      _isLoadingPermission = false;
    });

    if (!_isLimitReached) {
      _initYoutubePlayer();
    }
  }

  void _initYoutubePlayer() {
    _youtubeController = YoutubePlayerController(
      initialVideoId: widget.video.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: true,
        enableCaption: false,
        hideControls: true, // Hides native YouTube UI completely
        controlsVisibleAtStart: false,
      ),
    )..addListener(_onPlayerStateChange);

    // Watch duration timer
    _sessionWatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && !_isScreenRecordingDetected) {
        _totalWatchedSeconds++;
      }
    });

    _startHideControlsTimer();
  }

  void _onPlayerStateChange() {
    if (!mounted || _isLimitReached) return;

    final state = _youtubeController.value.playerState;
    final position = _youtubeController.value.position;
    final duration = _youtubeController.value.metaData.duration;

    setState(() {
      _isPlaying = _youtubeController.value.isPlaying;
      _currentPosition = position;
      _totalDuration = duration.inSeconds > 0
          ? duration
          : Duration(seconds: widget.video.durationSeconds);
    });

    // Check completion threshold (>80% watched or ended)
    if ((state == PlayerState.ended ||
            (_totalDuration.inSeconds > 0 &&
                position.inSeconds >= (_totalDuration.inSeconds * 0.85))) &&
        !_hasLoggedCompletion) {
      _hasLoggedCompletion = true;
      _recordWatchSession(isCompleted: true);
    }
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

    if (!_isLimitReached) {
      _youtubeController.removeListener(_onPlayerStateChange);
      _youtubeController.dispose();
    }

    SecurityService.disableSecureScreen();
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
                    : _buildPlayerView(),
      ),
    );
  }

  // --- SCREEN RECORDING DETECTED BLOCKED VIEW ---
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
              'Screen recording or screen capture software has been detected on your device. Video playback is paused to protect copyright content.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withAlpha(100)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.redAccent, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Stop screen recording to resume video playback.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Exit Video Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- LIMIT REACHED LOCKED VIEW ---
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
                border: Border.all(color: Colors.redAccent.withAlpha(100), width: 2),
              ),
              child: const Icon(Icons.lock_clock_rounded, size: 56, color: Colors.redAccent),
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
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Contact your administrator to request additional views.',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Back to Lessons', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- DEDICATED SECURE CUSTOM PLAYER VIEW ---
  Widget _buildPlayerView() {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 1. YouTube Player Viewport
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _youtubeController,
                showVideoProgressIndicator: false,
              ),
            ),
          ),

          // 2. Shielding Overlays (Blocking touch events on YouTube Logo & Title areas)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            width: 120,
            height: 60,
            child: Container(color: Colors.transparent),
          ),

          // 3. Custom Player Controls Overlay
          if (_showControls)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black.withAlpha(160),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar (Back button, Title, Views Remaining Chip)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
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
                                    Icon(Icons.shield_sharp, color: Color(0xFF10B981), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Protected Stream • Anti-Screen Recording Active',
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_permission != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF6366F1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.remove_red_eye_outlined, color: Colors.indigoAccent, size: 14),
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
                        ],
                      ),
                    ),

                    // Center Transport Controls (10s Rewind, Play/Pause, 10s Forward)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                          onPressed: () {
                            final current = _youtubeController.value.position;
                            _youtubeController.seekTo(current - const Duration(seconds: 10));
                            _startHideControlsTimer();
                          },
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            if (_isPlaying) {
                              _youtubeController.pause();
                            } else {
                              _youtubeController.play();
                            }
                            _startHideControlsTimer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                          onPressed: () {
                            final current = _youtubeController.value.position;
                            _youtubeController.seekTo(current + const Duration(seconds: 10));
                            _startHideControlsTimer();
                          },
                        ),
                      ],
                    ),

                    // Bottom Bar (Progress slider & Timestamps)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _currentPosition.inSeconds.toDouble().clamp(
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
                                  onChanged: (val) {
                                    _youtubeController.seekTo(Duration(seconds: val.toInt()));
                                    _startHideControlsTimer();
                                  },
                                ),
                              ),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
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
}
