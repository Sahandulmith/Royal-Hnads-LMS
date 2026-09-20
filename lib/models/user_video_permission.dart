import 'package:cloud_firestore/cloud_firestore.dart';

class UserVideoPermission {
  final String id;
  final String studentId;
  final String videoId;
  final int allowedViews;
  final int usedViews;
  final DateTime assignedAt;

  UserVideoPermission({
    required this.id,
    required this.studentId,
    required this.videoId,
    required this.allowedViews,
    required this.usedViews,
    required this.assignedAt,
  });

  int get remainingViews => (allowedViews - usedViews).clamp(0, allowedViews);
  bool get hasRemainingViews => remainingViews > 0;
  bool get isLimitReached => usedViews >= allowedViews;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'video_id': videoId,
      'allowed_views': allowedViews,
      'used_views': usedViews,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }

  factory UserVideoPermission.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserVideoPermission(
      id: docId,
      studentId: map['student_id'] ?? '',
      videoId: map['video_id'] ?? '',
      allowedViews: map['allowed_views'] ?? 1,
      usedViews: map['used_views'] ?? 0,
      assignedAt: parseDate(map['assigned_at']),
    );
  }
}
