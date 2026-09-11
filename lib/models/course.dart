class Course {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int videoCount;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    this.videoCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'video_count': videoCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Course.fromMap(Map<String, dynamic> map, String docId) {
    return Course(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      videoCount: map['video_count'] ?? 0,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
