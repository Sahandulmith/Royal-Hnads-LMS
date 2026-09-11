class Video {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final String youtubeId;
  final int durationSeconds;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.youtubeId,
    required this.durationSeconds,
    required this.createdAt,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final remainingSecs = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'youtube_id': youtubeId,
      'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Video.fromMap(Map<String, dynamic> map, String docId) {
    return Video(
      id: docId,
      courseId: map['course_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      youtubeId: map['youtube_id'] ?? '',
      durationSeconds: map['duration_seconds'] ?? 0,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
