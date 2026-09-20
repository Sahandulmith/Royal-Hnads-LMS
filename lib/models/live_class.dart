class LiveClass {
  final String id;
  final String title;
  final String description;
  final String classUrl;
  final String platform; // 'zoom', 'youtube', 'web'
  final bool isActive;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  LiveClass({
    required this.id,
    required this.title,
    required this.description,
    required this.classUrl,
    required this.platform,
    required this.isActive,
    this.scheduledAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'class_url': classUrl,
        'platform': platform,
        'is_active': isActive,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory LiveClass.fromMap(Map<String, dynamic> map, String docId) {
    return LiveClass(
      id: docId,
      title: map['title'] ?? 'Live Classroom',
      description: map['description'] ?? '',
      classUrl: map['class_url'] ?? '',
      platform: map['platform'] ?? 'web',
      isActive: map['is_active'] ?? false,
      scheduledAt: map['scheduled_at'] != null ? DateTime.tryParse(map['scheduled_at']) : null,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at']) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  LiveClass copyWith({
    String? id,
    String? title,
    String? description,
    String? classUrl,
    String? platform,
    bool? isActive,
    DateTime? scheduledAt,
    DateTime? createdAt,
  }) {
    return LiveClass(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      classUrl: classUrl ?? this.classUrl,
      platform: platform ?? this.platform,
      isActive: isActive ?? this.isActive,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
