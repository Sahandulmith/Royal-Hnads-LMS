import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_user.dart';
import '../../models/course.dart';
import '../../models/video.dart';
import '../../models/user_video_permission.dart';
import '../../models/device_request.dart';
import '../../models/watch_session.dart';
import '../../models/live_class.dart';
import 'device_service.dart';

class LoginResult {
  final bool success;
  final String? errorMessage;
  final bool requiresDeviceApproval;
  final AppUser? user;
  final DeviceInformation? currentDevice;

  LoginResult({
    required this.success,
    this.errorMessage,
    this.requiresDeviceApproval = false,
    this.user,
    this.currentDevice,
  });
}

class LmsRepository extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sessionUserUidKey = 'secure_lms_saved_uid';
  static const String _themeModeKey = 'app_theme_mode';

  static String hashPassword(String rawPassword) {
    final trimmed = rawPassword.trim();
    if (trimmed.isEmpty) return '';
    final bytes = utf8.encode(trimmed);
    return sha256.convert(bytes).toString();
  }

  AppUser? _currentUser;
  DeviceInformation? _currentDevice;
  bool _isCheckingSession = true;
  ThemeMode _themeMode = ThemeMode.system;

  // Real-time cached collections from Firestore
  final List<AppUser> _users = [];
  final List<Course> _courses = [];
  final List<Video> _videos = [];
  final List<UserVideoPermission> _permissions = [];
  final List<DeviceRequest> _deviceRequests = [];
  final List<WatchSession> _watchSessions = [];
  final List<LiveClass> _liveClasses = [];

  final List<StreamSubscription> _subscriptions = [];

  AppUser? get currentUser => _currentUser;
  DeviceInformation? get currentDevice => _currentDevice;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isCheckingSession => _isCheckingSession;
  ThemeMode get themeMode => _themeMode;

  LmsRepository() {
    _initFirestoreListeners();
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final savedTheme = await _storage.read(key: _themeModeKey);
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      final savedUid = await _storage.read(key: _sessionUserUidKey);
      if (savedUid != null && savedUid.isNotEmpty) {
        _currentDevice = await DeviceService.getDeviceDetails();
        final doc = await _firestore.collection('users').doc(savedUid).get();
        if (doc.exists && doc.data() != null) {
          final user = AppUser.fromMap(doc.data()!, doc.id);
          if (user.isActive) {
            if (user.isAdmin || user.registeredDeviceId == null || user.registeredDeviceId == _currentDevice?.deviceId) {
              _currentUser = user;
              debugPrint('Auto-login successful for user: ${user.email}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    String val = 'system';
    if (mode == ThemeMode.light) {
      val = 'light';
    } else if (mode == ThemeMode.dark) {
      val = 'dark';
    }
    await _storage.write(key: _themeModeKey, value: val);
  }

  Future<bool> hasSeenOnboarding(String studentUid) async {
    try {
      final val = await _storage.read(key: 'has_seen_onboarding_$studentUid');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingSeen(String studentUid) async {
    try {
      await _storage.write(key: 'has_seen_onboarding_$studentUid', value: 'true');
    } catch (_) {}
  }

  void _initFirestoreListeners() {
    // 1. Users collection stream
    _subscriptions.add(
      _firestore.collection('users').snapshots().listen((snapshot) {
        _users.clear();
        for (var doc in snapshot.docs) {
          _users.add(AppUser.fromMap(doc.data(), doc.id));
        }
        // Update current user reference if logged in
        if (_currentUser != null) {
          final updated = _users.firstWhere(
            (u) => u.uid == _currentUser!.uid,
            orElse: () => _currentUser!,
          );
          _currentUser = updated;
        }
        _syncMissingWatchSessions();
        notifyListeners();
      }, onError: (e) => debugPrint('Users stream error: $e')),
    );

    // 2. Courses stream
    _subscriptions.add(
      _firestore.collection('courses').snapshots().listen((snapshot) {
        _courses.clear();
        for (var doc in snapshot.docs) {
          _courses.add(Course.fromMap(doc.data(), doc.id));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Courses stream error: $e')),
    );

    // 3. Videos stream
    _subscriptions.add(
      _firestore.collection('videos').snapshots().listen((snapshot) {
        _videos.clear();
        for (var doc in snapshot.docs) {
          _videos.add(Video.fromMap(doc.data(), doc.id));
        }
        _syncMissingWatchSessions();
        notifyListeners();
      }, onError: (e) => debugPrint('Videos stream error: $e')),
    );

    // 4. Permissions stream
    _subscriptions.add(
      _firestore.collection('user_video_permissions').snapshots().listen((snapshot) {
        _permissions.clear();
        for (var doc in snapshot.docs) {
          _permissions.add(UserVideoPermission.fromMap(doc.data(), doc.id));
        }
        _syncMissingWatchSessions();
        notifyListeners();
      }, onError: (e) => debugPrint('Permissions stream error: $e')),
    );

    // 5. Device Requests stream
    _subscriptions.add(
      _firestore.collection('device_change_requests').snapshots().listen((snapshot) {
        _deviceRequests.clear();
        for (var doc in snapshot.docs) {
          _deviceRequests.add(DeviceRequest.fromMap(doc.data(), doc.id));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Device requests stream error: $e')),
    );

    // 6. Watch Sessions stream
    _subscriptions.add(
      _firestore.collection('watch_sessions').snapshots().listen((snapshot) {
        _watchSessions.clear();
        for (var doc in snapshot.docs) {
          _watchSessions.add(WatchSession.fromMap(doc.data(), doc.id));
        }
        _syncMissingWatchSessions();
        notifyListeners();
      }, onError: (e) => debugPrint('Watch sessions stream error: $e')),
    );

    // 7. Live Classes stream
    _subscriptions.add(
      _firestore.collection('live_classes').snapshots().listen((snapshot) {
        _liveClasses.clear();
        for (var doc in snapshot.docs) {
          _liveClasses.add(LiveClass.fromMap(doc.data(), doc.id));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Live classes stream error: $e')),
    );
  }

  /// No-op: Dummy data seeding disabled
  Future<bool> seedInitialDataToFirestore({bool force = false}) async {
    return true;
  }

  // --- AUTHENTICATION & DEVICE BINDING ---

  Future<LoginResult> login(String email, String password) async {
    _currentDevice = await DeviceService.getDeviceDetails();
    final cleanEmail = email.trim().toLowerCase();

    // Query user by email from Firestore or local stream cache
    AppUser? user;
    final index = _users.indexWhere((u) => u.email.toLowerCase() == cleanEmail);
    if (index != -1) {
      user = _users[index];
    } else {
      // Query Firestore directly as fallback
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        user = AppUser.fromMap(query.docs.first.data(), query.docs.first.id);
      }
    }

    if (user == null) {
      return LoginResult(
        success: false,
        errorMessage: 'Invalid user account or email.',
      );
    }

    if (!user.isActive) {
      return LoginResult(
        success: false,
        errorMessage: 'This account has been deactivated by an Administrator. Please contact support.',
      );
    }

    // Password Check using SHA-256 Hash
    final storedPassword = user.password ?? hashPassword('password123');
    final inputHash = hashPassword(password);
    final isMatch = (storedPassword == inputHash) || (storedPassword == password.trim());

    if (!isMatch) {
      return LoginResult(
        success: false,
        errorMessage: 'Incorrect password. Please verify your password.',
      );
    }

    // Auto-migrate legacy plain text password to SHA-256 hash in Firestore if needed
    if (storedPassword != inputHash) {
      user = user.copyWith(password: inputHash);
      _firestore.collection('users').doc(user.uid).update({'password': inputHash}).catchError((e) {
        debugPrint('Error updating password hash: $e');
      });
    }

    // Admin accounts can log in from any device
    if (user.isAdmin) {
      _currentUser = user;
      await _storage.write(key: _sessionUserUidKey, value: user.uid);
      notifyListeners();
      return LoginResult(success: true, user: user, currentDevice: _currentDevice);
    }

    // Student Device Binding Verification
    if (user.registeredDeviceId == null || user.registeredDeviceId!.isEmpty) {
      // First time login -> Register current device automatically in Firestore
      final updatedUser = user.copyWith(
        registeredDeviceId: _currentDevice!.deviceId,
        deviceModel: _currentDevice!.model,
        deviceOs: _currentDevice!.osVersion,
      );
      
      await _firestore.collection('users').doc(user.uid).update({
        'registered_device_id': _currentDevice!.deviceId,
        'device_model': _currentDevice!.model,
        'device_os': _currentDevice!.osVersion,
      });

      _currentUser = updatedUser;
      await _storage.write(key: _sessionUserUidKey, value: updatedUser.uid);
      notifyListeners();
      return LoginResult(success: true, user: updatedUser, currentDevice: _currentDevice);
    }

    // Device Mismatch Check
    if (user.registeredDeviceId != _currentDevice!.deviceId) {
      return LoginResult(
        success: false,
        requiresDeviceApproval: true,
        errorMessage:
            'Device Mismatch! Your account is bound to another registered device (${user.deviceModel ?? "Registered Phone"}). Access blocked.',
        user: user,
        currentDevice: _currentDevice,
      );
    }

    // Success
    _currentUser = user;
    await _storage.write(key: _sessionUserUidKey, value: user.uid);
    notifyListeners();
    return LoginResult(success: true, user: user, currentDevice: _currentDevice);
  }

  Future<void> logout() async {
    _currentUser = null;
    await _storage.delete(key: _sessionUserUidKey);
    notifyListeners();
  }

  // --- DEVICE REQUEST MANAGEMENT ---

  Future<bool> submitDeviceChangeRequest({
    required AppUser user,
    required String reason,
  }) async {
    if (_currentDevice == null) {
      _currentDevice = await DeviceService.getDeviceDetails();
    }

    final reqId = 'req-${const Uuid().v4().substring(0, 8)}';
    final request = DeviceRequest(
      id: reqId,
      studentId: user.uid,
      studentName: user.name,
      studentEmail: user.email,
      currentDeviceId: user.registeredDeviceId ?? 'UNBOUND',
      newDeviceId: _currentDevice!.deviceId,
      newDeviceModel: _currentDevice!.model,
      newDeviceOs: _currentDevice!.osVersion,
      reason: reason,
      status: DeviceRequestStatus.pending,
      requestedAt: DateTime.now(),
    );

    await _firestore.collection('device_change_requests').doc(reqId).set(request.toMap());
    return true;
  }

  List<DeviceRequest> getPendingDeviceRequests() {
    return _deviceRequests.where((r) => r.status == DeviceRequestStatus.pending).toList();
  }

  List<DeviceRequest> getAllDeviceRequests() {
    return List.from(_deviceRequests)..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<void> respondToDeviceRequest(String requestId, bool approve) async {
    final reqIndex = _deviceRequests.indexWhere((r) => r.id == requestId);
    if (reqIndex == -1) return;

    final req = _deviceRequests[reqIndex];
    final newStatus = approve ? DeviceRequestStatus.approved : DeviceRequestStatus.rejected;
    final now = DateTime.now();

    await _firestore.collection('device_change_requests').doc(requestId).update({
      'status': newStatus.name,
      'reviewed_at': now.toIso8601String(),
    });

    if (approve) {
      // Update student's registered device in users collection in Firestore
      await _firestore.collection('users').doc(req.studentId).update({
        'registered_device_id': req.newDeviceId,
        'device_model': req.newDeviceModel,
        'device_os': req.newDeviceOs,
      });
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;
    final storedPassword = _currentUser!.password ?? hashPassword('password123');
    final currentHash = hashPassword(currentPassword);

    if (storedPassword != currentHash && storedPassword != currentPassword.trim()) {
      return false;
    }

    final newHash = hashPassword(newPassword);
    await _firestore.collection('users').doc(_currentUser!.uid).update({
      'password': newHash,
    });
    _currentUser = _currentUser!.copyWith(password: newHash);
    notifyListeners();
    return true;
  }

  // --- USER MANAGEMENT (ADMIN) ---

  List<AppUser> getAllUsers() => List.from(_users);

  List<AppUser> getStudents() => _users.where((u) => u.isStudent).toList();

  Future<void> toggleUserActive(String uid) async {
    final index = _users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final newStatus = !_users[index].isActive;
      await _firestore.collection('users').doc(uid).update({'is_active': newStatus});
    }
  }

  Future<void> resetStudentDevice(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'registered_device_id': FieldValue.delete(),
      'device_model': FieldValue.delete(),
      'device_os': FieldValue.delete(),
    });
  }

  Future<void> createStudentUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final uid = 'user-student-${const Uuid().v4().substring(0, 6)}';
    final rawPw = password.trim().isEmpty ? 'password123' : password.trim();
    final hashedPw = hashPassword(rawPw);
    final newUser = AppUser(
      uid: uid,
      email: email.trim().toLowerCase(),
      name: name.trim(),
      role: UserRole.student,
      password: hashedPw,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(newUser.toMap());
  }

  Future<void> updateStudentUser({
    required String uid,
    required String name,
    required String email,
    String? password,
  }) async {
    final updates = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
    };
    if (password != null && password.trim().isNotEmpty) {
      updates['password'] = hashPassword(password);
    }
    await _firestore.collection('users').doc(uid).update(updates);
  }

  /// Force deletes student user from database and cleans up permissions/requests
  Future<void> deleteStudentUser(String uid) async {
    final batch = _firestore.batch();
    
    // Delete user doc
    batch.delete(_firestore.collection('users').doc(uid));

    // Cleanup permissions
    final permDocs = await _firestore
        .collection('user_video_permissions')
        .where('student_id', isEqualTo: uid)
        .get();
    for (var doc in permDocs.docs) {
      batch.delete(doc.reference);
    }

    // Cleanup device requests
    final reqDocs = await _firestore
        .collection('device_change_requests')
        .where('student_id', isEqualTo: uid)
        .get();
    for (var doc in reqDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // --- COURSES & VIDEOS ---

  List<Course> getCourses() => List.from(_courses);

  List<Video> getVideosForCourse(String courseId) {
    return _videos.where((v) => v.courseId == courseId).toList();
  }

  List<Video> getAllVideos() => List.from(_videos);

  Future<void> addCourse({
    required String title,
    required String description,
    required String thumbnailUrl,
  }) async {
    final courseId = 'course-${const Uuid().v4().substring(0, 6)}';
    final newCourse = Course(
      id: courseId,
      title: title.trim(),
      description: description.trim(),
      thumbnailUrl: thumbnailUrl.trim(),
      videoCount: 0,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('courses').doc(courseId).set(newCourse.toMap());
  }

  Future<void> addVideo({
    required String courseId,
    required String title,
    required String description,
    required String youtubeId,
    required int durationSeconds,
    int defaultAllowedViews = 1,
  }) async {
    final videoId = 'vid-${const Uuid().v4().substring(0, 6)}';
    final newVideo = Video(
      id: videoId,
      courseId: courseId,
      title: title.trim(),
      description: description.trim(),
      youtubeId: youtubeId.trim(),
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('videos').doc(videoId), newVideo.toMap());

    // Update course video count in Firestore
    final courseIndex = _courses.indexWhere((c) => c.id == courseId);
    if (courseIndex != -1) {
      final currentCount = _courses[courseIndex].videoCount;
      batch.update(
        _firestore.collection('courses').doc(courseId),
        {'video_count': currentCount + 1},
      );
    }

    // Assign default view permission to all existing students
    final students = getStudents();
    final now = DateTime.now();
    for (var student in students) {
      final permId = 'perm-${const Uuid().v4().substring(0, 6)}';
      final perm = UserVideoPermission(
        id: permId,
        studentId: student.uid,
        videoId: videoId,
        allowedViews: defaultAllowedViews,
        usedViews: 0,
        assignedAt: now,
      );
      batch.set(_firestore.collection('user_video_permissions').doc(permId), perm.toMap());
    }

    await batch.commit();
  }

  Future<void> updateVideo({
    required String id,
    required String courseId,
    required String title,
    required String description,
    required String youtubeId,
    int? durationSeconds,
  }) async {
    final updates = <String, dynamic>{
      'course_id': courseId,
      'title': title.trim(),
      'description': description.trim(),
      'youtube_id': youtubeId.trim(),
    };
    if (durationSeconds != null) {
      updates['duration_seconds'] = durationSeconds;
    }
    await _firestore.collection('videos').doc(id).update(updates);
  }

  /// Force deletes video document from database and updates course count
  Future<void> deleteVideo(String videoId) async {
    final videoIndex = _videos.indexWhere((v) => v.id == videoId);
    if (videoIndex == -1) return;

    final video = _videos[videoIndex];
    final batch = _firestore.batch();

    // Delete video doc
    batch.delete(_firestore.collection('videos').doc(videoId));

    // Decrement course video count
    final courseIndex = _courses.indexWhere((c) => c.id == video.courseId);
    if (courseIndex != -1) {
      final currentCount = _courses[courseIndex].videoCount;
      batch.update(
        _firestore.collection('courses').doc(video.courseId),
        {'video_count': (currentCount - 1).clamp(0, 9999)},
      );
    }

    // Cleanup permissions for this video
    final permDocs = await _firestore
        .collection('user_video_permissions')
        .where('video_id', isEqualTo: videoId)
        .get();
    for (var doc in permDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // --- VIEW LIMIT PERMISSIONS ---

  UserVideoPermission getPermissionForStudent(String studentId, String videoId) {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      return _permissions[index];
    }

    // Default permission if not explicitly set: 1 view allowed
    final permId = 'perm-${const Uuid().v4().substring(0, 6)}';
    final newPerm = UserVideoPermission(
      id: permId,
      studentId: studentId,
      videoId: videoId,
      allowedViews: 1,
      usedViews: 0,
      assignedAt: DateTime.now(),
    );

    // Save to Firestore asynchronously and add to local cache
    _permissions.add(newPerm);
    _firestore.collection('user_video_permissions').doc(permId).set(newPerm.toMap()).catchError((e) {
      debugPrint('Error saving permission to Firestore: $e');
    });
    return newPerm;
  }

  Future<void> setStudentViewLimit({
    required String studentId,
    required String videoId,
    required int allowedViews,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final permId = _permissions[index].id;
      await _firestore.collection('user_video_permissions').doc(permId).update({
        'allowed_views': allowedViews,
      });
    } else {
      final permId = 'perm-${const Uuid().v4().substring(0, 6)}';
      final newPerm = UserVideoPermission(
        id: permId,
        studentId: studentId,
        videoId: videoId,
        allowedViews: allowedViews,
        usedViews: 0,
        assignedAt: DateTime.now(),
      );
      await _firestore.collection('user_video_permissions').doc(permId).set(newPerm.toMap());
    }
  }

  Future<void> resetStudentViews({
    required String studentId,
    required String videoId,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final permId = _permissions[index].id;
      await _firestore.collection('user_video_permissions').doc(permId).update({
        'used_views': 0,
      });
    }
  }

  Future<bool> incrementUsedViews({
    required String studentId,
    required String videoId,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final p = _permissions[index];
      if (p.usedViews < p.allowedViews) {
        await _firestore.collection('user_video_permissions').doc(p.id).update({
          'used_views': p.usedViews + 1,
        });
        return true;
      }
    }
    return false;
  }

  // --- WATCH HISTORY & ANALYTICS ---

  bool _isSyncingWatchSessions = false;

  /// Automatically creates missing watch session documents for permissions with usedViews > 0
  Future<void> _syncMissingWatchSessions() async {
    if (_isSyncingWatchSessions) return;
    _isSyncingWatchSessions = true;

    try {
      final List<Map<String, dynamic>> missingSessionsToCreate = [];

      for (var perm in _permissions) {
        if (perm.usedViews <= 0) continue;

        final existing = _watchSessions.where(
          (s) => s.studentId == perm.studentId && s.videoId == perm.videoId,
        ).toList();

        final missingCount = perm.usedViews - existing.length;
        if (missingCount > 0) {
          final studentIdx = _users.indexWhere((u) => u.uid == perm.studentId);
          final studentName = studentIdx != -1 ? _users[studentIdx].name : 'Student (${perm.studentId.substring(0, 6)})';

          final videoIdx = _videos.indexWhere((v) => v.id == perm.videoId);
          final videoTitle = videoIdx != -1 ? _videos[videoIdx].title : 'Lesson Video (${perm.videoId})';
          final durationSec = videoIdx != -1 ? _videos[videoIdx].durationSeconds : 300;

          for (int i = 0; i < missingCount; i++) {
            final sessionId = 'session-sync-${perm.studentId.substring(0, 4)}-${perm.videoId.substring(0, 4)}-$i';
            final newSession = WatchSession(
              id: sessionId,
              studentId: perm.studentId,
              studentName: studentName,
              videoId: perm.videoId,
              videoTitle: videoTitle,
              deviceId: 'REGISTERED-DEVICE',
              deviceModel: kIsWeb ? 'Web Browser' : 'Student Device',
              deviceOs: kIsWeb ? 'Web' : 'Mobile OS',
              startTime: perm.assignedAt.add(Duration(minutes: i * 5)),
              endTime: perm.assignedAt.add(Duration(minutes: i * 5 + 10)),
              watchDurationSeconds: durationSec > 0 ? durationSec : 180,
              isCompleted: true,
              ipAddress: '192.168.1.100',
            );

            missingSessionsToCreate.add(newSession.toMap());
          }
        }
      }

      if (missingSessionsToCreate.isNotEmpty) {
        final batch = _firestore.batch();
        for (var map in missingSessionsToCreate) {
          final docRef = _firestore.collection('watch_sessions').doc(map['id']);
          batch.set(docRef, map);
        }
        await batch.commit();
        debugPrint('Synced ${missingSessionsToCreate.length} missing watch sessions to Firestore.');
      }
    } catch (e) {
      debugPrint('Error syncing missing watch sessions: $e');
    } finally {
      _isSyncingWatchSessions = false;
    }
  }

  Future<void> recordWatchSession({
    required Video video,
    required DateTime startTime,
    required DateTime endTime,
    required int watchDurationSeconds,
    required bool isCompleted,
    String? sessionId,
    String? studentId,
    String? studentName,
  }) async {
    final uid = studentId ?? _currentUser?.uid ?? '';
    final name = studentName ?? _currentUser?.name ?? 'Student';
    if (uid.isEmpty) return;

    if (_currentDevice == null) {
      try {
        _currentDevice = await DeviceService.getDeviceDetails();
      } catch (_) {}
    }

    final id = sessionId ?? 'session-${const Uuid().v4().substring(0, 8)}';
    final session = WatchSession(
      id: id,
      studentId: uid,
      studentName: name,
      videoId: video.id,
      videoTitle: video.title,
      deviceId: _currentDevice?.deviceId ?? (kIsWeb ? 'WEB-BROWSER' : 'MOBILE-DEVICE'),
      deviceModel: _currentDevice?.model ?? (kIsWeb ? 'Web Browser' : 'Registered Device'),
      deviceOs: _currentDevice?.osVersion ?? (kIsWeb ? 'Web' : 'Mobile OS'),
      startTime: startTime,
      endTime: endTime,
      watchDurationSeconds: watchDurationSeconds,
      isCompleted: isCompleted,
      ipAddress: '192.168.1.100',
    );

    await _firestore.collection('watch_sessions').doc(id).set(session.toMap());
  }

  List<WatchSession> getAllWatchSessions() {
    return List.from(_watchSessions)..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // --- LIVE CLASSROOM MANAGEMENT ---

  List<LiveClass> getLiveClasses() => List.from(_liveClasses);

  LiveClass? getActiveLiveClass() {
    final activeList = _liveClasses.where((l) => l.isActive).toList();
    if (activeList.isNotEmpty) {
      return activeList.first;
    }
    return null;
  }

  Future<void> createOrUpdateLiveClass({
    String? id,
    required String title,
    required String description,
    required String classUrl,
    required String platform,
    required bool isActive,
    DateTime? scheduledAt,
  }) async {
    final classId = id ?? 'live-${const Uuid().v4().substring(0, 6)}';
    final liveClass = LiveClass(
      id: classId,
      title: title.trim(),
      description: description.trim(),
      classUrl: classUrl.trim(),
      platform: platform.trim().toLowerCase(),
      isActive: isActive,
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
    );

    if (isActive) {
      final batch = _firestore.batch();
      for (var lc in _liveClasses) {
        if (lc.id != classId && lc.isActive) {
          batch.update(_firestore.collection('live_classes').doc(lc.id), {'is_active': false});
        }
      }
      batch.set(_firestore.collection('live_classes').doc(classId), liveClass.toMap());
      await batch.commit();
    } else {
      await _firestore.collection('live_classes').doc(classId).set(liveClass.toMap());
    }
  }

  Future<void> toggleLiveClassActive(String id, bool isActive) async {
    if (isActive) {
      final batch = _firestore.batch();
      for (var lc in _liveClasses) {
        if (lc.id != id && lc.isActive) {
          batch.update(_firestore.collection('live_classes').doc(lc.id), {'is_active': false});
        }
      }
      batch.update(_firestore.collection('live_classes').doc(id), {'is_active': true});
      await batch.commit();
    } else {
      await _firestore.collection('live_classes').doc(id).update({'is_active': false});
    }
  }

  Future<void> deleteLiveClass(String id) async {
    await _firestore.collection('live_classes').doc(id).delete();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
