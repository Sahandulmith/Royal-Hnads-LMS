enum DeviceRequestStatus { pending, approved, rejected }

class DeviceRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String currentDeviceId;
  final String newDeviceId;
  final String newDeviceModel;
  final String newDeviceOs;
  final String reason;
  final DeviceRequestStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;

  DeviceRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.currentDeviceId,
    required this.newDeviceId,
    required this.newDeviceModel,
    required this.newDeviceOs,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_email': studentEmail,
      'current_device_id': currentDeviceId,
      'new_device_id': newDeviceId,
      'new_device_model': newDeviceModel,
      'new_device_os': newDeviceOs,
      'reason': reason,
      'status': status.name,
      'requested_at': requestedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory DeviceRequest.fromMap(Map<String, dynamic> map, String docId) {
    return DeviceRequest(
      id: docId,
      studentId: map['student_id'] ?? '',
      studentName: map['student_name'] ?? '',
      studentEmail: map['student_email'] ?? '',
      currentDeviceId: map['current_device_id'] ?? '',
      newDeviceId: map['new_device_id'] ?? '',
      newDeviceModel: map['new_device_model'] ?? '',
      newDeviceOs: map['new_device_os'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] == 'approved'
          ? DeviceRequestStatus.approved
          : map['status'] == 'rejected'
              ? DeviceRequestStatus.rejected
              : DeviceRequestStatus.pending,
      requestedAt: map['requested_at'] != null 
          ? DateTime.tryParse(map['requested_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      reviewedAt: map['reviewed_at'] != null ? DateTime.tryParse(map['reviewed_at'].toString()) : null,
    );
  }
}
