import 'package:flutter/foundation.dart';
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
  AppUser? _currentUser;
  DeviceInformation? _currentDevice;

  // In-memory mock database collections
  final List<AppUser> _users = [];
  final List<Course> _courses = [];
  final List<Video> _videos = [];
  final List<UserVideoPermission> _permissions = [];
  final List<DeviceRequest> _deviceRequests = [];
  final List<WatchSession> _watchSessions = [];

  AppUser? get currentUser => _currentUser;
  DeviceInformation? get currentDevice => _currentDevice;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  LmsRepository() {
    _initializeSeedData();
  }

  void _initializeSeedData() {
    final now = DateTime.now();

    // 1. Initial Users
    _users.addAll([
      AppUser(
        uid: 'user-admin-1',
        email: 'admin@lms.com',
        name: 'System Administrator',
        role: UserRole.admin,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      AppUser(
        uid: 'user-student-1',
        email: 'student1@lms.com',
        name: 'Alex Johnson',
        role: UserRole.student,
        isActive: true,
        registeredDeviceId: 'DEV-SIMULATED-STUDENT-1',
        deviceModel: 'Samsung Galaxy S22',
        deviceOs: 'Android 14',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      AppUser(
        uid: 'user-student-2',
        email: 'student2@lms.com',
        name: 'Sophia Martinez',
        role: UserRole.student,
        isActive: true,
        registeredDeviceId: null, // First-time login will bind current device
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      AppUser(
        uid: 'user-student-3',
        email: 'student3@lms.com',
        name: 'David Smith (Blocked)',
        role: UserRole.student,
        isActive: false, // Inactive account
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ]);

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
    _courses.addAll([course1, course2]);

    // 3. Initial Videos (Hosted on YouTube, YouTube IDs)
    _videos.addAll([
      Video(
        id: 'vid-1',
        courseId: 'course-1',
        title: 'Lecture 01: Calculus Limits & Continuity',
        description: 'Introduction to limit laws, continuous functions, and epsilon-delta definitions.',
        youtubeId: 'kJQP7kiw5Fk', // Sample educational YouTube video ID
        durationSeconds: 600,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
      Video(
        id: 'vid-2',
        courseId: 'course-1',
        title: 'Lecture 02: Derivatives and Chain Rule',
        description: 'Derivation techniques, implicit differentiation, and real-world applications.',
        youtubeId: 'dQw4w9WgXcQ',
        durationSeconds: 750,
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      Video(
        id: 'vid-3',
        courseId: 'course-2',
        title: 'Module 01: Newton\'s Laws of Motion',
        description: 'Detailed analysis of inertial reference frames and force vector calculations.',
        youtubeId: 'L_LUpnjgPso',
        durationSeconds: 900,
        createdAt: now.subtract(const Duration(days: 18)),
      ),
      Video(
        id: 'vid-4',
        courseId: 'course-2',
        title: 'Module 02: Energy Conservation & Momentum',
        description: 'Elastic vs inelastic collisions and potential energy field calculations.',
        youtubeId: '3JZ_D3ELwOQ',
        durationSeconds: 840,
        createdAt: now.subtract(const Duration(days: 16)),
      ),
    ]);

    // 4. Initial Permissions (View Limits)
    _permissions.addAll([
      UserVideoPermission(
        id: 'perm-1',
        studentId: 'user-student-1',
        videoId: 'vid-1',
        allowedViews: 2,
        usedViews: 1, // 1 remaining
        assignedAt: now.subtract(const Duration(days: 10)),
      ),
      UserVideoPermission(
        id: 'perm-2',
        studentId: 'user-student-1',
        videoId: 'vid-2',
        allowedViews: 1,
        usedViews: 1, // 0 remaining -> LIMIT REACHED
        assignedAt: now.subtract(const Duration(days: 10)),
      ),
      UserVideoPermission(
        id: 'perm-3',
        studentId: 'user-student-2',
        videoId: 'vid-1',
        allowedViews: 3,
        usedViews: 0, // 3 remaining
        assignedAt: now.subtract(const Duration(days: 4)),
      ),
    ]);

    // 5. Initial Device Request
    _deviceRequests.add(
      DeviceRequest(
        id: 'req-1',
        studentId: 'user-student-1',
        studentName: 'Alex Johnson',
        studentEmail: 'student1@lms.com',
        currentDeviceId: 'DEV-SIMULATED-STUDENT-1',
        newDeviceId: 'DEV-NEW-PHONE-XYZ',
        newDeviceModel: 'iPhone 15 Pro',
        newDeviceOs: 'iOS 17.4',
        reason: 'Upgraded to a new phone and lost access to the old device.',
        status: DeviceRequestStatus.pending,
        requestedAt: now.subtract(const Duration(hours: 3)),
      ),
    );

    // 6. Initial Watch Sessions
    _watchSessions.addAll([
      WatchSession(
        id: 'session-1',
        studentId: 'user-student-1',
        studentName: 'Alex Johnson',
        videoId: 'vid-1',
        videoTitle: 'Lecture 01: Calculus Limits & Continuity',
        deviceId: 'DEV-SIMULATED-STUDENT-1',
        deviceModel: 'Samsung Galaxy S22',
        deviceOs: 'Android 14',
        startTime: now.subtract(const Duration(days: 2, hours: 4)),
        endTime: now.subtract(const Duration(days: 2, hours: 3, minutes: 50)),
        watchDurationSeconds: 600,
        isCompleted: true,
        ipAddress: '192.168.1.45',
      ),
      WatchSession(
        id: 'session-2',
        studentId: 'user-student-1',
        studentName: 'Alex Johnson',
        videoId: 'vid-2',
        videoTitle: 'Lecture 02: Derivatives and Chain Rule',
        deviceId: 'DEV-SIMULATED-STUDENT-1',
        deviceModel: 'Samsung Galaxy S22',
        deviceOs: 'Android 14',
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1, minutes: 47)),
        watchDurationSeconds: 750,
        isCompleted: true,
        ipAddress: '192.168.1.45',
      ),
    ]);
  }

  // --- AUTHENTICATION & DEVICE BINDING ---

  Future<LoginResult> login(String email, String password) async {
    _currentDevice = await DeviceService.getDeviceDetails();
    final cleanEmail = email.trim().toLowerCase();

    final index = _users.indexWhere((u) => u.email.toLowerCase() == cleanEmail);
    if (index == -1) {
      return LoginResult(
        success: false,
        errorMessage: 'Invalid user account or password.',
      );
    }

    final user = _users[index];

    if (!user.isActive) {
      return LoginResult(
        success: false,
        errorMessage: 'This account has been deactivated by an Administrator. Please contact support.',
      );
    }

    // Admin accounts can log in from any device
    if (user.isAdmin) {
      _currentUser = user;
      notifyListeners();
      return LoginResult(success: true, user: user, currentDevice: _currentDevice);
    }

    // Student Device Binding Verification
    if (user.registeredDeviceId == null || user.registeredDeviceId!.isEmpty) {
      // First time login -> Register current device automatically
      final updatedUser = user.copyWith(
        registeredDeviceId: _currentDevice!.deviceId,
        deviceModel: _currentDevice!.model,
        deviceOs: _currentDevice!.osVersion,
      );
      _users[index] = updatedUser;
      _currentUser = updatedUser;
      notifyListeners();
      return LoginResult(success: true, user: updatedUser, currentDevice: _currentDevice);
    }

    // Device Mismatch Check
    if (user.registeredDeviceId != _currentDevice!.deviceId) {
      return LoginResult(
        success: false,
        requiresDeviceApproval: true,
        errorMessage: 'Device Mismatch! Your account is bound to another registered device (${user.deviceModel ?? "Registered Phone"}). Access blocked.',
        user: user,
        currentDevice: _currentDevice,
      );
    }

    // Success
    _currentUser = user;
    notifyListeners();
    return LoginResult(success: true, user: user, currentDevice: _currentDevice);
  }

  void logout() {
    _currentUser = null;
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

    final request = DeviceRequest(
      id: 'req-${const Uuid().v4().substring(0, 8)}',
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

    _deviceRequests.add(request);
    notifyListeners();
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

    _deviceRequests[reqIndex] = DeviceRequest(
      id: req.id,
      studentId: req.studentId,
      studentName: req.studentName,
      studentEmail: req.studentEmail,
      currentDeviceId: req.currentDeviceId,
      newDeviceId: req.newDeviceId,
      newDeviceModel: req.newDeviceModel,
      newDeviceOs: req.newDeviceOs,
      reason: req.reason,
      status: newStatus,
      requestedAt: req.requestedAt,
      reviewedAt: DateTime.now(),
    );

    if (approve) {
      // Update student's registered device in users collection
      final userIndex = _users.indexWhere((u) => u.uid == req.studentId);
      if (userIndex != -1) {
        _users[userIndex] = _users[userIndex].copyWith(
          registeredDeviceId: req.newDeviceId,
          deviceModel: req.newDeviceModel,
          deviceOs: req.newDeviceOs,
        );
      }
    }

    notifyListeners();
  }

  // --- USER MANAGEMENT (ADMIN) ---

  List<AppUser> getAllUsers() => List.from(_users);

  List<AppUser> getStudents() => _users.where((u) => u.isStudent).toList();

  Future<void> toggleUserActive(String uid) async {
    final index = _users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final user = _users[index];
      _users[index] = user.copyWith(isActive: !user.isActive);
      notifyListeners();
    }
  }

  Future<void> createStudentUser({required String name, required String email}) async {
    final newUser = AppUser(
      uid: 'user-student-${const Uuid().v4().substring(0, 6)}',
      email: email.trim().toLowerCase(),
      name: name.trim(),
      role: UserRole.student,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _users.add(newUser);
    notifyListeners();
  }

  // --- COURSES & VIDEOS ---

  List<Course> getCourses() => List.from(_courses);

  List<Video> getVideosForCourse(String courseId) {
    return _videos.where((v) => v.courseId == courseId).toList();
  }

  List<Video> getAllVideos() => List.from(_videos);

  Future<void> addVideo({
    required String courseId,
    required String title,
    required String description,
    required String youtubeId,
    required int durationSeconds,
  }) async {
    final newVideo = Video(
      id: 'vid-${const Uuid().v4().substring(0, 6)}',
      courseId: courseId,
      title: title.trim(),
      description: description.trim(),
      youtubeId: youtubeId.trim(),
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );
    _videos.add(newVideo);

    // Update course video count
    final courseIndex = _courses.indexWhere((c) => c.id == courseId);
    if (courseIndex != -1) {
      final c = _courses[courseIndex];
      _courses[courseIndex] = Course(
        id: c.id,
        title: c.title,
        description: c.description,
        thumbnailUrl: c.thumbnailUrl,
        videoCount: c.videoCount + 1,
        createdAt: c.createdAt,
      );
    }

    notifyListeners();
  }

  // --- VIEW LIMIT PERMISSIONS ---

  UserVideoPermission getPermissionForStudent(String studentId, String videoId) {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      return _permissions[index];
    }
    // Default permission if not explicitly set: 1 view allowed
    final newPerm = UserVideoPermission(
      id: 'perm-${const Uuid().v4().substring(0, 6)}',
      studentId: studentId,
      videoId: videoId,
      allowedViews: 1,
      usedViews: 0,
      assignedAt: DateTime.now(),
    );
    _permissions.add(newPerm);
    return newPerm;
  }

  Future<void> setStudentViewLimit({
    required String studentId,
    required String videoId,
    required int allowedViews,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final p = _permissions[index];
      _permissions[index] = UserVideoPermission(
        id: p.id,
        studentId: p.studentId,
        videoId: p.videoId,
        allowedViews: allowedViews,
        usedViews: p.usedViews,
        assignedAt: p.assignedAt,
      );
    } else {
      _permissions.add(
        UserVideoPermission(
          id: 'perm-${const Uuid().v4().substring(0, 6)}',
          studentId: studentId,
          videoId: videoId,
          allowedViews: allowedViews,
          usedViews: 0,
          assignedAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> resetStudentViews({
    required String studentId,
    required String videoId,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final p = _permissions[index];
      _permissions[index] = UserVideoPermission(
        id: p.id,
        studentId: p.studentId,
        videoId: p.videoId,
        allowedViews: p.allowedViews,
        usedViews: 0,
        assignedAt: p.assignedAt,
      );
      notifyListeners();
    }
  }

  // Increments view count when student completes or watches a video
  Future<bool> incrementUsedViews({
    required String studentId,
    required String videoId,
  }) async {
    final index = _permissions.indexWhere((p) => p.studentId == studentId && p.videoId == videoId);
    if (index != -1) {
      final p = _permissions[index];
      if (p.usedViews < p.allowedViews) {
        _permissions[index] = UserVideoPermission(
          id: p.id,
          studentId: p.studentId,
          videoId: p.videoId,
          allowedViews: p.allowedViews,
          usedViews: p.usedViews + 1,
          assignedAt: p.assignedAt,
        );
        notifyListeners();
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

    final session = WatchSession(
      id: 'session-${const Uuid().v4().substring(0, 8)}',
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

    _watchSessions.add(session);

    // Also update usedViews if completed
    if (isCompleted) {
      await incrementUsedViews(studentId: _currentUser!.uid, videoId: video.id);
    }

    notifyListeners();
  }

  List<WatchSession> getAllWatchSessions() {
    return List.from(_watchSessions)..sort((a, b) => b.startTime.compareTo(a.startTime));
  }
}
