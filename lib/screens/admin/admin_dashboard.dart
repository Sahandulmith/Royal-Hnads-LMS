import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/services/lms_repository.dart';
import '../../models/app_user.dart';
import '../../models/video.dart';
import '../../models/course.dart';
import '../../models/device_request.dart';
import '../../models/watch_session.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6), size: 26),
            SizedBox(width: 10),
            Text(
              'LMS Admin Control Center',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Logout Admin',
            onPressed: () => repo.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Students (${students.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.video_collection_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Videos & Classes (${videos.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                children: [
                  Icon(Icons.lock_reset, size: 16),
                  SizedBox(width: 6),
                  Text('View Limits & Resets'),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.phonelink_setup, size: 16),
                  const SizedBox(width: 6),
                  Text('Device Approvals (${pendingRequests.length})'),
                  if (pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                      child: Text(
                        '${pendingRequests.length}',
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Analytics & Logs (${watchSessions.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Overview Quick Stats Bar
          _buildQuickStatsBar(students.length, pendingRequests.length, watchSessions.length, videos.length),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentsTab(context, repo, students),
                _buildVideosTab(context, repo, videos),
                _buildViewLimitsTab(context, repo, students, videos),
                _buildDeviceRequestsTab(context, repo, repo.getAllDeviceRequests()),
                _buildAnalyticsTab(context, watchSessions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STATS BAR ---
  Widget _buildQuickStatsBar(int studentCount, int pendingReqs, int sessionCount, int videoCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF1E293B).withAlpha(150),
      child: Row(
        children: [
          _buildStatItem('Total Students', '$studentCount', Icons.person_outline, Colors.blueAccent),
          const SizedBox(width: 16),
          _buildStatItem('Recorded Videos', '$videoCount', Icons.ondemand_video, Colors.purpleAccent),
          const SizedBox(width: 16),
          _buildStatItem('Pending Device Reqs', '$pendingReqs', Icons.devices, Colors.orangeAccent),
          const SizedBox(width: 16),
          _buildStatItem('Total Watch Sessions', '$sessionCount', Icons.history, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(context, repo),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Add Student Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final s = students[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withAlpha(40),
                  child: Text(
                    s.name.substring(0, 1).toUpperCase(),
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
                          Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
                Switch(
                  value: s.isActive,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (_) => repo.toggleUserActive(s.uid),
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                repo.createStudentUser(name: nameCtrl.text, email: emailCtrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create Student'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVideoDialog(context, repo, courses),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_to_photos_rounded, color: Colors.white),
        label: const Text('Add YouTube Video Lesson', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final v = videos[index];
          final course = courses.firstWhere((c) => c.id == v.courseId, orElse: () => Course(id: '', title: 'General', description: '', thumbnailUrl: '', createdAt: DateTime.now()));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
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
                    errorBuilder: (_, __, ___) => Container(width: 90, height: 60, color: Colors.black26, child: const Icon(Icons.video_collection, color: Colors.white38)),
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddVideoDialog(BuildContext context, LmsRepository repo, List<Course> courses) {
    final titleCtrl = TextEditingController();
    final youtubeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCourseId = courses.isNotEmpty ? courses.first.id : 'course-1';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Recorded YouTube Class', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Lesson Title', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: youtubeCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'YouTube Video ID or Link', labelStyle: TextStyle(color: Colors.white70), hintText: 'e.g. kJQP7kiw5Fk'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Lesson Description', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && youtubeCtrl.text.isNotEmpty) {
                // Extract video id if full url is pasted
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
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save Lesson'),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: VIEWING LIMITS & PERMISSIONS ---
  Widget _buildViewLimitsTab(BuildContext context, LmsRepository repo, List<AppUser> students, List<Video> videos) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: students.length,
      itemBuilder: (context, sIdx) {
        final student = students[sIdx];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(student.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${student.email})', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
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
