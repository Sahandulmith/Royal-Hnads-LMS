import 'package:cloud_firestore/cloud_firestore.dart';

class WatchSession {
  final String id;
  final String studentId;
  final String studentName;
  final String videoId;
  final String videoTitle;
  final String deviceId;
  final String deviceModel;
  final String deviceOs;
  final DateTime startTime;
  final DateTime endTime;
  final int watchDurationSeconds;
  final bool isCompleted;
  final String? ipAddress;

  WatchSession({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.videoId,
    required this.videoTitle,
    required this.deviceId,
    required this.deviceModel,
    required this.deviceOs,
    required this.startTime,
    required this.endTime,
    required this.watchDurationSeconds,
    required this.isCompleted,
    this.ipAddress,
  });

  String get formattedDuration {
    final mins = watchDurationSeconds ~/ 60;
    final secs = watchDurationSeconds % 60;
    return '${mins}m ${secs}s';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'video_id': videoId,
      'video_title': videoTitle,
      'device_id': deviceId,
      'device_model': deviceModel,
      'device_os': deviceOs,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'watch_duration_seconds': watchDurationSeconds,
      'is_completed': isCompleted,
      'ip_address': ipAddress,
    };
  }

  factory WatchSession.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return WatchSession(
      id: docId,
      studentId: map['student_id'] ?? '',
      studentName: map['student_name'] ?? '',
      videoId: map['video_id'] ?? '',
      videoTitle: map['video_title'] ?? '',
      deviceId: map['device_id'] ?? '',
      deviceModel: map['device_model'] ?? '',
      deviceOs: map['device_os'] ?? '',
      startTime: parseDate(map['start_time']),
      endTime: parseDate(map['end_time']),
      watchDurationSeconds: map['watch_duration_seconds'] ?? 0,
      isCompleted: map['is_completed'] ?? false,
      ipAddress: map['ip_address'],
    );
  }
}
