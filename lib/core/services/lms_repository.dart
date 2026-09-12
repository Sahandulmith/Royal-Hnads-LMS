import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  final List<StreamSubscription> _subscriptions = [];
  bool _isInitialized = false;

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
        notifyListeners();

        // Seed data if database is empty on first startup
        if (!_isInitialized && snapshot.docs.isEmpty) {
          _isInitialized = true;
          seedInitialDataToFirestore();
        }
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
        notifyListeners();
      }, onError: (e) => debugPrint('Watch sessions stream error: $e')),
    );
  }

  /// Populate initial seed records to Firestore if DB is freshly created
  Future<bool> seedInitialDataToFirestore({bool force = false}) async {
    try {
      if (!force) {
        final existingUsers = await _firestore.collection('users').get();
        if (existingUsers.docs.isNotEmpty) {
          debugPrint('Firestore database already contains users. Skipping seed.');
          return true;
        }
      }

      final batch = _firestore.batch();
      final now = DateTime.now();

      final defaultHash = hashPassword('password123');

      // 1. Initial Users
      final adminUser = AppUser(
        uid: 'user-admin-1',
        email: 'admin@lms.com',
        name: 'System Administrator',
        role: UserRole.admin,
        isActive: true,
        password: defaultHash,
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final student1 = AppUser(
        uid: 'user-student-1',
        email: 'student1@lms.com',
        name: 'Alex Johnson',
        role: UserRole.student,
        isActive: true,
        password: defaultHash,
        registeredDeviceId: 'DEV-SIMULATED-STUDENT-1',
        deviceModel: 'Samsung Galaxy S22',
        deviceOs: 'Android 14',
        createdAt: now.subtract(const Duration(days: 15)),
      );

      final student2 = AppUser(
        uid: 'user-student-2',
        email: 'student2@lms.com',
        name: 'Sophia Martinez',
        role: UserRole.student,
        isActive: true,
        password: defaultHash,
        createdAt: now.subtract(const Duration(days: 5)),
      );

      batch.set(_firestore.collection('users').doc(adminUser.uid), adminUser.toMap());
      batch.set(_firestore.collection('users').doc(student1.uid), student1.toMap());
      batch.set(_firestore.collection('users').doc(student2.uid), student2.toMap());

      // 2. Initial Courses
      final course1 = Course(
        id: 'course-1',
        title: 'Advanced Mathematics 101',
        description: 'Recorded lectures covering Calculus, Linear Algebra, and Differential Equations.',
        thumbnailUrl: 'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=600',
        videoCount: 2,
        createdAt: now.subtract(const Duration(days: 25)),
      );

      final course2 = Course(
        id: 'course-2',
        title: 'Physics & Quantum Mechanics',
        description: 'Comprehensive video series on Classical Dynamics and Thermodynamics.',
        thumbnailUrl: 'https://images.unsplash.com/photo-1636466497217-26a8cbeaf0aa?w=600',
        videoCount: 2,
        createdAt: now.subtract(const Duration(days: 20)),
      );

      batch.set(_firestore.collection('courses').doc(course1.id), course1.toMap());
      batch.set(_firestore.collection('courses').doc(course2.id), course2.toMap());

      // 3. Initial Videos
      final vid1 = Video(
        id: 'vid-1',
        courseId: 'course-1',
        title: 'Lecture 01: Calculus Limits & Continuity',
        description: 'Introduction to limit laws, continuous functions, and epsilon-delta definitions.',
        youtubeId: 'kJQP7kiw5Fk',
        durationSeconds: 600,
        createdAt: now.subtract(const Duration(days: 24)),
      );

      final vid2 = Video(
        id: 'vid-2',
        courseId: 'course-1',
        title: 'Lecture 02: Derivatives and Chain Rule',
        description: 'Derivation techniques, implicit differentiation, and real-world applications.',
        youtubeId: 'dQw4w9WgXcQ',
        durationSeconds: 750,
        createdAt: now.subtract(const Duration(days: 22)),
      );

      final vid3 = Video(
        id: 'vid-3',
        courseId: 'course-2',
        title: 'Module 01: Newton\'s Laws of Motion',
        description: 'Detailed analysis of inertial reference frames and force vector calculations.',
        youtubeId: 'L_LUpnjgPso',
        durationSeconds: 900,
        createdAt: now.subtract(const Duration(days: 18)),
      );

      final vid4 = Video(
        id: 'vid-4',
        courseId: 'course-2',
        title: 'Module 02: Energy Conservation & Momentum',
        description: 'Elastic vs inelastic collisions and potential energy field calculations.',
        youtubeId: '3JZ_D3ELwOQ',
        durationSeconds: 840,
        createdAt: now.subtract(const Duration(days: 16)),
      );

      batch.set(_firestore.collection('videos').doc(vid1.id), vid1.toMap());
      batch.set(_firestore.collection('videos').doc(vid2.id), vid2.toMap());
      batch.set(_firestore.collection('videos').doc(vid3.id), vid3.toMap());
      batch.set(_firestore.collection('videos').doc(vid4.id), vid4.toMap());

      // 4. Initial View Permissions
      final perm1 = UserVideoPermission(
        id: 'perm-1',
        studentId: 'user-student-1',
        videoId: 'vid-1',
        allowedViews: 2,
        usedViews: 1,
        assignedAt: now.subtract(const Duration(days: 10)),
      );

      final perm2 = UserVideoPermission(
        id: 'perm-2',
        studentId: 'user-student-1',
        videoId: 'vid-2',
        allowedViews: 1,
        usedViews: 1,
        assignedAt: now.subtract(const Duration(days: 10)),
      );

      batch.set(_firestore.collection('user_video_permissions').doc(perm1.id), perm1.toMap());
      batch.set(_firestore.collection('user_video_permissions').doc(perm2.id), perm2.toMap());

      await batch.commit();
      debugPrint('Firestore seed data successfully populated.');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error seeding initial data to Firestore: $e');
      _isInitialized = false;
      return false;
    }
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
  }) async {
    await _firestore.collection('videos').doc(id).update({
      'course_id': courseId,
      'title': title.trim(),
      'description': description.trim(),
      'youtube_id': youtubeId.trim(),
    });
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

  Future<void> recordWatchSession({
    required Video video,
    required DateTime startTime,
    required DateTime endTime,
    required int watchDurationSeconds,
    required bool isCompleted,
  }) async {
    if (_currentUser == null) return;
    _currentDevice ??= await DeviceService.getDeviceDetails();

    final sessionId = 'session-${const Uuid().v4().substring(0, 8)}';
    final session = WatchSession(
      id: sessionId,
      studentId: _currentUser!.uid,
      studentName: _currentUser!.name,
      videoId: video.id,
      videoTitle: video.title,
      deviceId: _currentDevice!.deviceId,
      deviceModel: _currentDevice!.model,
      deviceOs: _currentDevice!.osVersion,
      startTime: startTime,
      endTime: endTime,
      watchDurationSeconds: watchDurationSeconds,
      isCompleted: isCompleted,
      ipAddress: '192.168.1.100',
    );

    await _firestore.collection('watch_sessions').doc(sessionId).set(session.toMap());

    // Also update usedViews if completed
    if (isCompleted) {
      await incrementUsedViews(studentId: _currentUser!.uid, videoId: video.id);
    }
  }

  List<WatchSession> getAllWatchSessions() {
    return List.from(_watchSessions)..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
