enum UserRole { student, admin }

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final bool isActive;
  final String? registeredDeviceId;
  final String? deviceModel;
  final String? deviceOs;
  final String? password;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.isActive = true,
    this.registeredDeviceId,
    this.deviceModel,
    this.deviceOs,
    this.password,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isStudent => role == UserRole.student;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'is_active': isActive,
      'registered_device_id': registeredDeviceId,
      'device_model': deviceModel,
      'device_os': deviceOs,
      'password': password ?? '',
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String docId) {
    return AppUser(
      uid: docId,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] == 'admin' ? UserRole.admin : UserRole.student,
      isActive: map['is_active'] ?? true,
      registeredDeviceId: map['registered_device_id'],
      deviceModel: map['device_model'],
      deviceOs: map['device_os'],
      password: map['password'] ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }

  AppUser copyWith({
    String? email,
    String? name,
    UserRole? role,
    bool? isActive,
    String? registeredDeviceId,
    String? deviceModel,
    String? deviceOs,
    String? password,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      registeredDeviceId: registeredDeviceId ?? this.registeredDeviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceOs: deviceOs ?? this.deviceOs,
      password: password ?? this.password,
      createdAt: createdAt,
    );
  }
}
