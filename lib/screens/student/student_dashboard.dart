import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/lms_repository.dart';
import '../../models/course.dart';
import '../../models/video.dart';
import 'video_player_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String _selectedCourseId = 'ALL';

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);
    final user = repo.currentUser;
    final device = repo.currentDevice;

    if (user == null) return const SizedBox.shrink();

    final courses = repo.getCourses();
    final allVideos = repo.getAllVideos();

    final filteredVideos = _selectedCourseId == 'ALL'
        ? allVideos
        : repo.getVideosForCourse(_selectedCourseId);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device != null ? 'Bound: ${device.model}' : 'Registered Device',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Sign Out',
            onPressed: () => repo.logout(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Banner / Info Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4338CA).withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'STUDENT LMS PORTAL',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Recorded Classroom Lessons',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Watch assigned videos inside the secure player. Viewing limits apply as configured by your instructor.',
                            style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Course Filter Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFilterChip('ALL', 'All Enrolled Courses'),
                  ...courses.map((c) => _buildFilterChip(c.id, c.title)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Lessons List Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Available Recorded Lessons',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Video Cards Grid/List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = filteredVideos[index];
                  final perm = repo.getPermissionForStudent(user.uid, video.id);
                  final course = courses.firstWhere(
                    (c) => c.id == video.courseId,
                    orElse: () => Course(
                      id: '',
                      title: 'Class Lesson',
                      description: '',
                      thumbnailUrl: '',
                      createdAt: DateTime.now(),
                    ),
                  );

                  return _buildVideoCard(context, repo, video, course, perm);
                },
                childCount: filteredVideos.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String title) {
    final isSelected = _selectedCourseId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(title),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCourseId = id),
        selectedColor: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildVideoCard(
    BuildContext context,
    LmsRepository repo,
    Video video,
    Course course,
    dynamic perm,
  ) {
    final isLimitReached = perm.isLimitReached;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimitReached ? Colors.redAccent.withAlpha(80) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Header Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail / Play Preview Box
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://img.youtube.com/vi/${video.youtubeId}/hqdefault.jpg',
                        width: 100,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 68,
                          color: const Color(0xFF0F172A),
                          child: const Center(
                            child: Icon(Icons.video_library, color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            isLimitReached ? Icons.lock : Icons.play_arrow_rounded,
                            color: isLimitReached ? Colors.redAccent : Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.title,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Color(0xFF94A3B8), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            video.formattedDuration,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF334155), height: 1),

          // Bottom Actions & View Limit Chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // View Limit Status Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLimitReached
                        ? Colors.redAccent.withAlpha(30)
                        : Colors.greenAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLimitReached
                          ? Colors.redAccent.withAlpha(80)
                          : Colors.greenAccent.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLimitReached ? Icons.lock : Icons.remove_red_eye,
                        color: isLimitReached ? Colors.redAccent : Colors.greenAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLimitReached
                            ? 'Limit Reached (${perm.usedViews}/${perm.allowedViews} used)'
                            : '${perm.remainingViews} View Remaining (${perm.usedViews}/${perm.allowedViews} used)',
                        style: TextStyle(
                          color: isLimitReached ? Colors.redAccent : Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Play Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(video: video),
                      ),
                    );
                  },
                  icon: Icon(
                    isLimitReached ? Icons.lock : Icons.play_arrow_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isLimitReached ? 'Locked' : 'Watch Now',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLimitReached ? const Color(0xFF334155) : const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
