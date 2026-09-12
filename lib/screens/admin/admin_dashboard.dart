import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/services/lms_repository.dart';
import '../../core/services/image_helper.dart';
import '../../models/app_user.dart';
import '../../models/video.dart';
import '../../models/course.dart';
import '../../models/device_request.dart';
import '../../models/watch_session.dart';
import '../profile/profile_screen.dart';
import '../widgets/curved_bottom_nav_bar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTabIndex = 0;
  String _limitSearchQuery = '';

  final List<CurvedNavItem> _adminNavItems = const [
    CurvedNavItem(icon: Icons.people_alt_rounded, label: 'Students'),
    CurvedNavItem(icon: Icons.video_collection_rounded, label: 'Videos'),
    CurvedNavItem(icon: Icons.phonelink_setup_rounded, label: 'Limits'),
    CurvedNavItem(icon: Icons.analytics_rounded, label: 'Analytics'),
    CurvedNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _appBarBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _textColor => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSubColor => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _borderColor => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _inputBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);
    final user = repo.currentUser;

    if (user == null || !user.isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: Text('Access Denied: Admin privileges required.', style: TextStyle(color: Colors.white))),
      );
    }

    final students = repo.getStudents();
    final pendingRequests = repo.getPendingDeviceRequests();
    final watchSessions = repo.getAllWatchSessions();
    final videos = repo.getAllVideos();

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _appBarBg,
        elevation: _isDark ? 0 : 1,
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
                errorBuilder: (_, __, ___) => const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6), size: 26),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Royal Hands Admin',
              style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Overview Quick Stats Bar
          _buildQuickStatsBar(students.length, pendingRequests.length, watchSessions.length, videos.length),

          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildStudentsTab(context, repo, students),
                _buildVideosTab(context, repo, videos),
                _buildLimitsAndDeviceRequestsTab(context, repo, students, videos, pendingRequests),
                _buildAnalyticsTab(context, watchSessions),
                const ProfileScreen(isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedBottomNavBar(
        items: _adminNavItems,
        selectedIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: _cardBg,
        activeColor: const Color(0xFF8B5CF6),
        inactiveColor: _textSubColor,
      ),
    );
  }

  Widget _buildLimitsAndDeviceRequestsTab(
    BuildContext context,
    LmsRepository repo,
    List<AppUser> students,
    List<Video> videos,
    List<DeviceRequest> pendingRequests,
  ) {
    final filteredStudents = students.where((s) {
      final q = _limitSearchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 90),
      children: [
        if (pendingRequests.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending Device Transfer Approvals (${pendingRequests.length})',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...repo.getAllDeviceRequests().map((req) => _buildSingleDeviceRequestCard(context, repo, req)),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),
        ],
        // Search Bar for Student Limits
        TextField(
          onChanged: (val) => setState(() => _limitSearchQuery = val),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search student by name or email...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B5CF6), size: 20),
            suffixIcon: _limitSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () => setState(() => _limitSearchQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filteredStudents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No student accounts match your search.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ...filteredStudents.map((student) => _buildSingleStudentLimitsCard(context, repo, student, videos)),
      ],
    );
  }

  // --- TAB 0: DASHBOARD OVERVIEW SCREEN ---
  Widget _buildDashboardTab(
    BuildContext context,
    LmsRepository repo,
    List<AppUser> students,
    List<Video> videos,
    List<DeviceRequest> pendingRequests,
    List<WatchSession> watchSessions,
  ) {
    final activeStudentsCount = students.where((s) => s.isActive).length;
    final totalWatchMinutes = watchSessions.fold<int>(0, (sum, s) => sum + (s.watchDurationSeconds ~/ 60));
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      children: [
        // 1. Welcome Header Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF8B5CF6), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Admin',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Royal Hands LMS Control Center • ${students.length} Registered Students ($activeStudentsCount Active)',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Summary Metric Tiles Grid (2x2)
        const Text(
          'System Overview & Metrics',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Students',
                value: '${students.length}',
                subtitle: '$activeStudentsCount Active',
                icon: Icons.people_alt_rounded,
                color: Colors.blueAccent,
                onTap: () => setState(() => _selectedTabIndex = 0),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricTile(
                title: 'Recorded Videos',
                value: '${videos.length}',
                subtitle: '${repo.getCourses().length} Courses',
                icon: Icons.video_collection_rounded,
                color: Colors.purpleAccent,
                onTap: () => setState(() => _selectedTabIndex = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Requests',
                value: '${pendingRequests.length}',
                subtitle: pendingRequests.isEmpty ? 'All cleared' : 'Action required',
                icon: Icons.phonelink_setup_rounded,
                color: Colors.orangeAccent,
                isAlert: pendingRequests.isNotEmpty,
                onTap: () => setState(() => _selectedTabIndex = 2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricTile(
                title: 'Total Watch Time',
                value: '$totalWatchMinutes m',
                subtitle: '${watchSessions.length} Sessions',
                icon: Icons.analytics_rounded,
                color: Colors.greenAccent,
                onTap: () => setState(() => _selectedTabIndex = 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. Quick Action Shortcut Buttons
        const Text(
          'Quick Actions',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Student',
                color: const Color(0xFF6366F1),
                onTap: () => _showAddStudentDialog(context, repo),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.video_call_rounded,
                label: 'Add Lesson',
                color: const Color(0xFF8B5CF6),
                onTap: () => _showAddVideoDialog(context, repo, repo.getCourses()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.phonelink_lock_rounded,
                label: 'Student Limits',
                color: const Color(0xFF10B981),
                onTap: () => setState(() => _selectedTabIndex = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. Pending Device Approvals Direct Action Widget
        if (pendingRequests.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending Device Transfers (${pendingRequests.length})',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...pendingRequests.take(2).map((req) => _buildSingleDeviceRequestCard(context, repo, req)),
          if (pendingRequests.length > 2)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _selectedTabIndex = 2),
                icon: const Icon(Icons.arrow_forward, color: Colors.orangeAccent, size: 16),
                label: Text('View all ${pendingRequests.length} pending requests', style: const TextStyle(color: Colors.orangeAccent)),
              ),
            ),
          const SizedBox(height: 20),
        ],

        // 5. Recent Watch Sessions Feed Widget
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Watch Sessions',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTabIndex = 3),
              child: const Text('View All', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (watchSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Center(
              child: Text('No watch history recorded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
          )
        else
          ...watchSessions.take(3).map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: s.isCompleted ? Colors.greenAccent.withAlpha(30) : Colors.amberAccent.withAlpha(30),
                    child: Icon(
                      s.isCompleted ? Icons.check_circle_outline : Icons.timelapse,
                      color: s.isCompleted ? Colors.greenAccent : Colors.amberAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.studentName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(s.videoTitle, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Watched: ${s.formattedDuration} • ${dateFormat.format(s.startTime)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isAlert = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAlert ? Colors.orangeAccent : const Color(0xFF334155)),
          boxShadow: [
            if (isAlert)
              BoxShadow(
                color: Colors.orangeAccent.withAlpha(30),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                color: isAlert ? Colors.orangeAccent : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(40),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withAlpha(100)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- STATS BAR ---
  Widget _buildQuickStatsBar(int studentCount, int pendingReqs, int sessionCount, int videoCount) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: _isDark ? const Color(0xFF1E293B).withAlpha(180) : Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatItem('Total Students', '$studentCount', Icons.person_outline_rounded, const Color(0xFF3B82F6), onTap: () => setState(() => _selectedTabIndex = 0)),
          const SizedBox(width: 12),
          _buildStatItem('Recorded Videos', '$videoCount', Icons.ondemand_video_rounded, const Color(0xFFA855F7), onTap: () => setState(() => _selectedTabIndex = 1)),
          const SizedBox(width: 12),
          _buildStatItem('Pending Requests', '$pendingReqs', Icons.phonelink_setup_rounded, const Color(0xFFF59E0B), isAlert: pendingReqs > 0, onTap: () => setState(() => _selectedTabIndex = 2)),
          const SizedBox(width: 12),
          _buildStatItem('Total Sessions', '$sessionCount', Icons.history_rounded, const Color(0xFF10B981), onTap: () => setState(() => _selectedTabIndex = 3)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, {bool isAlert = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 145,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAlert ? Colors.amber.withAlpha(160) : _borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isAlert ? (_isDark ? Colors.amberAccent : const Color(0xFFD97706)) : _textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textSubColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: STUDENT MANAGEMENT ---
  Widget _buildStudentsTab(BuildContext context, LmsRepository repo, List<AppUser> students) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddStudentDialog(context, repo),
          backgroundColor: const Color(0xFF8B5CF6),
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          label: const Text('Add Student Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final s = students[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withAlpha(40),
                  child: Text(
                    s.name.isNotEmpty ? s.name.substring(0, 1).toUpperCase() : 'S',
                    style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.name, style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.isActive ? Colors.greenAccent.withAlpha(30) : Colors.redAccent.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.isActive ? 'ACTIVE' : 'DEACTIVATED',
                              style: TextStyle(
                                color: s.isActive ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s.email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phonelink_lock, color: Colors.orangeAccent, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            s.registeredDeviceId != null
                                ? 'Bound Device: ${s.deviceModel ?? s.registeredDeviceId}'
                                : 'Bound Device: None (Will bind on next login)',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF6366F1), size: 20),
                      tooltip: 'Edit Student Details',
                      onPressed: () => _showEditStudentDialog(context, repo, s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Force Remove Student',
                      onPressed: () => _showDeleteStudentDialog(context, repo, s),
                    ),
                    Switch(
                      value: s.isActive,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (_) => repo.toggleUserActive(s.uid),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context, LmsRepository repo) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add New Student Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Student Email',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Account Password',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Minimum 6 characters',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                repo.createStudentUser(
                  name: nameCtrl.text,
                  email: emailCtrl.text,
                  password: passwordCtrl.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create Student'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(BuildContext context, LmsRepository repo, AppUser student) {
    final nameCtrl = TextEditingController(text: student.name);
    final emailCtrl = TextEditingController(text: student.email);
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Edit Student: ${student.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Student Email', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New Password (leave blank to keep current)',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Enter new password if changing',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                repo.updateStudentUser(
                  uid: student.uid,
                  name: nameCtrl.text,
                  email: emailCtrl.text,
                  password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudentDialog(BuildContext context, LmsRepository repo, AppUser student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Force Deletion', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete student account "${student.name}" (${student.email})?\n\nThis will remove the student document and all associated permissions and device requests from the database.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              repo.deleteStudentUser(student.uid);
              Navigator.pop(context);
            },
            child: const Text('Force Delete Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: VIDEOS & CLASSES MANAGER ---
  Widget _buildVideosTab(BuildContext context, LmsRepository repo, List<Video> videos) {
    final courses = repo.getCourses();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withAlpha(90),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddCourseDialog(context, repo),
                  icon: const Icon(Icons.library_add_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Add Course',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withAlpha(90),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddVideoDialog(context, repo, courses),
                  icon: const Icon(Icons.add_to_photos_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Add Video Lesson',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final v = videos[index];
          final course = courses.firstWhere(
            (c) => c.id == v.courseId,
            orElse: () => Course(id: '', title: 'General', description: '', thumbnailUrl: '', createdAt: DateTime.now()),
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://img.youtube.com/vi/${v.youtubeId}/hqdefault.jpg',
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 60,
                      color: Colors.black26,
                      child: const Icon(Icons.video_collection, color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('YouTube ID: ${v.youtubeId} • Duration: ${v.formattedDuration}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF8B5CF6), size: 22),
                      tooltip: 'Edit Video Details',
                      onPressed: () => _showEditVideoDialog(context, repo, v, courses),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                      tooltip: 'Delete Video Lesson',
                      onPressed: () => _showDeleteVideoDialog(context, repo, v),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditVideoDialog(BuildContext context, LmsRepository repo, Video video, List<Course> courses) {
    final titleCtrl = TextEditingController(text: video.title);
    final youtubeCtrl = TextEditingController(text: video.youtubeId);
    final descCtrl = TextEditingController(text: video.description);
    String selectedCourseId = courses.any((c) => c.id == video.courseId) ? video.courseId : (courses.isNotEmpty ? courses.first.id : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Edit Recorded YouTube Lesson', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Course Category:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: selectedCourseId,
                  dropdownColor: const Color(0xFF0F172A),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: courses.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCourseId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Lesson Title', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: youtubeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'YouTube Video ID or Link',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Lesson Description', labelStyle: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && youtubeCtrl.text.isNotEmpty) {
                  String rawId = youtubeCtrl.text.trim();
                  if (rawId.contains('v=')) {
                    rawId = rawId.split('v=').last.split('&').first;
                  } else if (rawId.contains('youtu.be/')) {
                    rawId = rawId.split('youtu.be/').last.split('?').first;
                  }

                  repo.updateVideo(
                    id: video.id,
                    courseId: selectedCourseId,
                    title: titleCtrl.text,
                    description: descCtrl.text,
                    youtubeId: rawId,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteVideoDialog(BuildContext context, LmsRepository repo, Video video) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Video Deletion', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete lesson "${video.title}"?\n\nThis will remove the video document from the database and decrement course video count.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              repo.deleteVideo(video.id);
              Navigator.pop(context);
            },
            child: const Text('Force Delete Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, LmsRepository repo) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final thumbnailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add New Course Category', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Course Title', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Course Description', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: thumbnailCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Thumbnail (Base64 string or image URL)',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'Paste Base64 data URL or HTTP link',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                repo.addCourse(
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  thumbnailUrl: thumbnailCtrl.text.trim().isNotEmpty
                      ? thumbnailCtrl.text.trim()
                      : 'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=600',
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create Course'),
          ),
        ],
      ),
    );
  }

  void _showAddVideoDialog(BuildContext context, LmsRepository repo, List<Course> courses) {
    final titleCtrl = TextEditingController();
    final youtubeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCourseId = courses.isNotEmpty ? courses.first.id : 'course-1';
    int selectedDefaultViews = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add Recorded YouTube Class', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Course:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: selectedCourseId,
                  dropdownColor: const Color(0xFF0F172A),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: courses.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCourseId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Lesson Title', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: youtubeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'YouTube Video ID or Link',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'e.g. kJQP7kiw5Fk',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Lesson Description', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 14),
                const Text('Default Student View Limit:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  value: selectedDefaultViews,
                  dropdownColor: const Color(0xFF0F172A),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: [1, 2, 3, 5, 10, 15, 20].map((limit) {
                    return DropdownMenuItem<int>(
                      value: limit,
                      child: Text('$limit View${limit > 1 ? 's' : ''} (Assign to all students)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDefaultViews = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && youtubeCtrl.text.isNotEmpty) {
                  String rawId = youtubeCtrl.text.trim();
                  if (rawId.contains('v=')) {
                    rawId = rawId.split('v=').last.split('&').first;
                  } else if (rawId.contains('youtu.be/')) {
                    rawId = rawId.split('youtu.be/').last.split('?').first;
                  }

                  repo.addVideo(
                    courseId: selectedCourseId,
                    title: titleCtrl.text,
                    description: descCtrl.text,
                    youtubeId: rawId,
                    durationSeconds: 600,
                    defaultAllowedViews: selectedDefaultViews,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Lesson'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDeviceRequestCard(BuildContext context, LmsRepository repo, DeviceRequest req) {
    final isPending = req.status == DeviceRequestStatus.pending;
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? Colors.orangeAccent.withAlpha(80) : _borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phonelink_setup, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.studentName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(req.studentEmail, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: req.status == DeviceRequestStatus.approved
                      ? Colors.greenAccent.withAlpha(30)
                      : req.status == DeviceRequestStatus.rejected
                          ? Colors.redAccent.withAlpha(30)
                          : Colors.orangeAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  req.status.name.toUpperCase(),
                  style: TextStyle(
                    color: req.status == DeviceRequestStatus.approved
                        ? Colors.greenAccent
                        : req.status == DeviceRequestStatus.rejected
                            ? Colors.redAccent
                            : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Requested Device: ${req.newDeviceModel} (${req.newDeviceOs})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('New Device ID: ${req.newDeviceId}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 6),
                Text('Reason: "${req.reason}"', style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text('Requested on: ${dateFormat.format(req.requestedAt)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => repo.respondToDeviceRequest(req.id, false),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                  child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => repo.respondToDeviceRequest(req.id, true),
                  icon: const Icon(Icons.check, color: Colors.white, size: 16),
                  label: const Text('Approve & Bind Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleStudentLimitsCard(BuildContext context, LmsRepository repo, AppUser student, List<Video> videos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(student.name, style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('(${student.email})', style: TextStyle(color: _textSubColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 8),
          ...videos.map((v) {
            final perm = repo.getPermissionForStudent(student.uid, v.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Allowed: ${perm.allowedViews} views | Used: ${perm.usedViews} | Remaining: ${perm.remainingViews}',
                          style: TextStyle(
                            color: perm.isLimitReached ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Set Limit Dropdown / Button
                  PopupMenuButton<int>(
                    tooltip: 'Change Max Views',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text('Limit: ${perm.allowedViews}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                    onSelected: (newLimit) {
                      repo.setStudentViewLimit(studentId: student.uid, videoId: v.id, allowedViews: newLimit);
                    },
                    itemBuilder: (_) => [1, 2, 3, 5, 10]
                        .map((limit) => PopupMenuItem(value: limit, child: Text('Allow $limit Views')))
                        .toList(),
                  ),

                  const SizedBox(width: 8),

                  // Reset Views Button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.orangeAccent, size: 20),
                    tooltip: 'Reset Used Views',
                    onPressed: () {
                      repo.resetStudentViews(studentId: student.uid, videoId: v.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reset view count for ${student.name} on "${v.title}"'), backgroundColor: Colors.orangeAccent),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- TAB 3: VIEWING LIMITS & PERMISSIONS ---
  Widget _buildViewLimitsTab(BuildContext context, LmsRepository repo, List<AppUser> students, List<Video> videos) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
      itemCount: students.length,
      itemBuilder: (context, sIdx) {
        return _buildSingleStudentLimitsCard(context, repo, students[sIdx], videos);
      },
    );
  }

  // --- TAB 4: DEVICE APPROVAL DESK ---
  Widget _buildDeviceRequestsTab(BuildContext context, LmsRepository repo, List<DeviceRequest> requests) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 48, color: Colors.greenAccent),
            SizedBox(height: 12),
            Text('No device transfer requests pending.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final isPending = req.status == DeviceRequestStatus.pending;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPending ? Colors.orangeAccent.withAlpha(80) : const Color(0xFF334155),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phonelink_setup, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req.studentName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(req.studentEmail, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: req.status == DeviceRequestStatus.approved
                          ? Colors.greenAccent.withAlpha(30)
                          : req.status == DeviceRequestStatus.rejected
                              ? Colors.redAccent.withAlpha(30)
                              : Colors.orangeAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      req.status.name.toUpperCase(),
                      style: TextStyle(
                        color: req.status == DeviceRequestStatus.approved
                            ? Colors.greenAccent
                            : req.status == DeviceRequestStatus.rejected
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Requested Device: ${req.newDeviceModel} (${req.newDeviceOs})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('New Device ID: ${req.newDeviceId}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('Reason: "${req.reason}"', style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text('Requested on: ${dateFormat.format(req.requestedAt)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => repo.respondToDeviceRequest(req.id, false),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => repo.respondToDeviceRequest(req.id, true),
                      icon: const Icon(Icons.check, color: Colors.white, size: 16),
                      label: const Text('Approve & Bind Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 5: WATCH HISTORY & ANALYTICS ---
  Widget _buildAnalyticsTab(BuildContext context, List<WatchSession> sessions) {
    if (sessions.isEmpty) {
      return const Center(child: Text('No watch sessions recorded yet.', style: TextStyle(color: Colors.white54)));
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final s = sessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: s.isCompleted ? Colors.greenAccent.withAlpha(30) : Colors.orangeAccent.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  s.isCompleted ? Icons.check_circle_outline : Icons.timelapse,
                  color: s.isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(s.studentName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: s.isCompleted ? Colors.greenAccent.withAlpha(30) : Colors.amberAccent.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s.isCompleted ? 'COMPLETED' : 'PARTIAL WATCH',
                            style: TextStyle(
                              color: s.isCompleted ? Colors.greenAccent : Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(s.videoTitle, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Watched: ${s.formattedDuration} • Device: ${s.deviceModel} (${s.deviceOs})',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Session Start: ${dateFormat.format(s.startTime)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
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
