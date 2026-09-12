import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/services/lms_repository.dart';
import '../../models/course.dart';
import '../../models/video.dart';
import '../profile/profile_screen.dart';
import '../widgets/curved_bottom_nav_bar.dart';
import 'video_player_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedTabIndex = 0;
  String _selectedCourseId = 'ALL';

  final List<CurvedNavItem> _navItems = const [
    CurvedNavItem(icon: Icons.home_rounded, label: 'Home'),
    CurvedNavItem(icon: Icons.bar_chart_rounded, label: 'History'),
    CurvedNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);
    final user = repo.currentUser;
    final device = repo.currentDevice;

    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSubColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final navBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final navInactive = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withAlpha(30),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/royal hands.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: Color(0xFF6366F1), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: TextStyle(
                    color: textColor,
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
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildLessonsTab(context, repo, user, isDark, textColor, textSubColor),
          _buildHistoryTab(context, repo, user, isDark, textColor, textSubColor),
          const ProfileScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: CurvedBottomNavBar(
        items: _navItems,
        selectedIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: navBarBg,
        activeColor: const Color(0xFF6366F1),
        inactiveColor: navInactive,
      ),
    );
  }

  // --- TAB 0: HOME / LESSONS ---
  Widget _buildLessonsTab(
    BuildContext context,
    LmsRepository repo,
    dynamic user,
    bool isDark,
    Color textColor,
    Color textSubColor,
  ) {
    final courses = repo.getCourses();
    final allVideos = repo.getAllVideos();

    final filteredVideos = _selectedCourseId == 'ALL'
        ? allVideos
        : repo.getVideosForCourse(_selectedCourseId);

    return CustomScrollView(
      slivers: [
        // Banner / Info Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1E1B4B), Color(0xFF312E81)]
                      : const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4338CA).withAlpha(100)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                _buildFilterChip('ALL', 'All Enrolled Courses', isDark),
                ...courses.map((c) => _buildFilterChip(c.id, c.title, isDark)),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Lessons List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Available Recorded Lessons',
              style: TextStyle(
                color: textColor,
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

                return _buildVideoCard(context, repo, video, course, perm, isDark, textColor, textSubColor);
              },
              childCount: filteredVideos.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _buildFilterChip(String id, String title, bool isDark) {
    final isSelected = _selectedCourseId == id;
    final chipBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final unselectedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(title),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCourseId = id),
        selectedColor: const Color(0xFF6366F1),
        backgroundColor: chipBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : unselectedText,
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
    bool isDark,
    Color textColor,
    Color textSubColor,
  ) {
    final isLimitReached = perm.isLimitReached;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimitReached ? Colors.redAccent.withAlpha(80) : borderColor,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          child: Center(
                            child: Icon(Icons.video_library, color: isDark ? Colors.white38 : Colors.black38),
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
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: textSubColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            video.formattedDuration,
                            style: TextStyle(color: textSubColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Bottom Actions & View Limit Chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLimitReached
                          ? Colors.redAccent.withAlpha(25)
                          : (isDark ? Colors.greenAccent.withAlpha(25) : const Color(0xFFDCFCE7)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLimitReached
                            ? Colors.redAccent.withAlpha(80)
                            : (isDark ? Colors.greenAccent.withAlpha(80) : const Color(0xFF86EFAC)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLimitReached ? Icons.lock_outline_rounded : Icons.remove_red_eye_rounded,
                          color: isLimitReached ? Colors.redAccent : (isDark ? Colors.greenAccent : const Color(0xFF15803D)),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isLimitReached
                                ? 'Limit Reached (${perm.usedViews}/${perm.allowedViews} used)'
                                : '${perm.remainingViews} ${perm.remainingViews == 1 ? "View" : "Views"} Remaining (${perm.usedViews}/${perm.allowedViews} used)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLimitReached ? Colors.redAccent : (isDark ? Colors.greenAccent : const Color(0xFF15803D)),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isLimitReached ? 'Locked' : 'Watch Now',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLimitReached ? (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)) : const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MY WATCH HISTORY ---
  Widget _buildHistoryTab(
    BuildContext context,
    LmsRepository repo,
    dynamic user,
    bool isDark,
    Color textColor,
    Color textSubColor,
  ) {
    final allSessions = repo.getAllWatchSessions();
    final mySessions = allSessions.where((s) => s.studentId == user.uid).toList();
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (mySessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: textSubColor),
            const SizedBox(height: 12),
            Text(
              'No watch history recorded yet.',
              style: TextStyle(color: textSubColor, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
      itemCount: mySessions.length,
      itemBuilder: (context, index) {
        final s = mySessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: s.isCompleted
                      ? Colors.greenAccent.withAlpha(30)
                      : Colors.orangeAccent.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  s.isCompleted ? Icons.check_circle_outline : Icons.timelapse,
                  color: s.isCompleted ? (isDark ? Colors.greenAccent : const Color(0xFF15803D)) : (isDark ? Colors.orangeAccent : const Color(0xFFD97706)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.videoTitle,
                      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Watch Duration: ${s.formattedDuration} • Status: ${s.isCompleted ? "Completed" : "Partial"}',
                      style: TextStyle(color: textSubColor, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Watched on: ${dateFormat.format(s.startTime)}',
                      style: TextStyle(color: textSubColor.withAlpha(180), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
