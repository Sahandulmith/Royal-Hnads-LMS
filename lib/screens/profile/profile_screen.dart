import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/lms_repository.dart';
import '../../core/services/update_service.dart';
import '../../core/services/web_image_picker.dart';
import '../widgets/update_dialog.dart';
import '../widgets/user_avatar.dart';
import '../student/student_onboarding_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded;

  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isUpdating = false;
  bool _isCheckingUpdate = false;
  bool _isUploadingImage = false;
  String _currentAppVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _currentAppVersion = info.version);
        return;
      }
    } catch (_) {}
    final ver = await UpdateService.getCurrentAppVersion();
    if (mounted && ver.isNotEmpty) {
      setState(() => _currentAppVersion = ver);
    }
  }

  Future<void> _handleManualUpdateCheck() async {
    setState(() => _isCheckingUpdate = true);
    final updateInfo = await UpdateService.checkForUpdates(isManualCheck: true);
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (updateInfo.hasUpdate) {
      UpdateAvailableDialog.show(context, updateInfo);
    } else {
      _showSnackBar(
        updateInfo.currentVersion.isNotEmpty
            ? 'You are on the latest version of Royal Hands (v${updateInfo.currentVersion}). No update required.'
            : 'You are on the latest version of Royal Hands. No update required.',
        const Color(0xFF10B981),
      );
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source, LmsRepository repo, String uid) async {
    try {
      Uint8List? bytes;
      int fileSizeInBytes = 0;
      String mimeType = 'image/jpeg';

      if (kIsWeb) {
        // Pure Web File Picker (bypasses mobile plugin method channels entirely)
        final webResult = await pickWebImage();
        if (webResult == null) {
          // User canceled file dialog or no file selected
          return;
        }
        bytes = webResult.bytes;
        fileSizeInBytes = webResult.size;
        mimeType = webResult.type;
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile == null) return;
        fileSizeInBytes = await pickedFile.length();
        bytes = await pickedFile.readAsBytes();
        mimeType = pickedFile.mimeType ?? 'image/jpeg';
      }

      if (bytes == null || bytes.isEmpty || fileSizeInBytes <= 0) return;

      // 🛑 ENFORCE 5MB MAXIMUM FILE SIZE LIMIT (5,242,880 Bytes)
      const maxSizeBytes = 5 * 1024 * 1024;
      if (fileSizeInBytes > maxSizeBytes) {
        final sizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(2);
        throw Exception('Selected image size ($sizeInMB MB) exceeds 5MB limit. Please choose a smaller photo.');
      }


      setState(() => _isUploadingImage = true);

      final base64String = base64Encode(bytes);
      final base64Image = 'data:$mimeType;base64,$base64String';

      await repo.updateUserProfileImage(uid, base64Image);

      if (mounted) {
        _showSnackBar('Profile picture updated successfully!', const Color(0xFF10B981));
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      if (mounted) {
        final errStr = e.toString().replaceAll('Exception:', '').trim();
        _showSnackBar(errStr, Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }




  void _showImageOptionsBottomSheet(BuildContext context, LmsRepository repo, String uid, String? currentBase64) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Picture',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF6366F1),
                child: Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
              title: Text(
                kIsWeb ? 'Choose Image File' : 'Choose from Gallery',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery, repo, uid);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera, repo, uid);
                },
              ),
            if (currentBase64 != null && currentBase64.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.delete_forever_rounded, color: Colors.white),
                ),
                title: const Text('Remove Current Picture', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isUploadingImage = true);
                  await repo.updateUserProfileImage(uid, null);
                  if (mounted) {
                    setState(() => _isUploadingImage = false);
                    _showSnackBar('Profile picture removed.', Colors.orangeAccent);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final currentPw = _currentPasswordCtrl.text.trim();
    final newPw = _newPasswordCtrl.text.trim();
    final confirmPw = _confirmPasswordCtrl.text.trim();

    if (currentPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnackBar('Please fill in all password fields.', Colors.redAccent);
      return;
    }

    if (newPw.length < 6) {
      _showSnackBar('New password must be at least 6 characters long.', Colors.redAccent);
      return;
    }

    if (newPw != confirmPw) {
      _showSnackBar('New passwords do not match.', Colors.redAccent);
      return;
    }

    setState(() => _isUpdating = true);

    final repo = Provider.of<LmsRepository>(context, listen: false);
    final success = await repo.changePassword(
      currentPassword: currentPw,
      newPassword: newPw,
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (success) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _showSnackBar('Password updated successfully!', Colors.greenAccent);
    } else {
      _showSnackBar('Current password is incorrect.', Colors.redAccent);
    }
  }

  void _showSnackBar(String msg, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, LmsRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              'Confirm Log Out',
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your Royal Hands account?\n\nYou will need to sign in again to access recorded classes.',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              repo.logout();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);
    final user = repo.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSubColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (user == null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(child: Text('Not authenticated', style: TextStyle(color: textColor))),
      );
    }

    final dateFormat = DateFormat('MMMM dd, yyyy');

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 90.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Avatar Header
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            profileImageBase64: user.profileImageBase64,
                            name: user.name,
                            radius: 44,
                            enablePreview: true,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _isUploadingImage
                                  ? null
                                  : () => _showImageOptionsBottomSheet(context, repo, user.uid, user.profileImageBase64),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardBg, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(60),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: _isUploadingImage
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        user.name,
                        style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.isAdmin
                              ? Colors.purpleAccent.withAlpha(30)
                              : Colors.indigoAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: user.isAdmin ? Colors.purpleAccent : Colors.indigoAccent,
                          ),
                        ),
                        child: Text(
                          user.role.name.toUpperCase(),
                          style: TextStyle(
                            color: user.isAdmin ? Colors.purpleAccent : Colors.indigoAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. App Appearance & Theme Selection Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'App Appearance & Theme',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select your theme mode preference. System Default follows your device settings.',
                        style: TextStyle(color: textSubColor, fontSize: 12),
                      ),
                      Divider(color: cardBorder, height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildThemeChip(
                              context: context,
                              repo: repo,
                              mode: ThemeMode.system,
                              label: 'System',
                              icon: Icons.brightness_auto_rounded,
                              isDark: isDark,
                              cardBorder: cardBorder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildThemeChip(
                              context: context,
                              repo: repo,
                              mode: ThemeMode.light,
                              label: 'Light',
                              icon: Icons.light_mode_rounded,
                              isDark: isDark,
                              cardBorder: cardBorder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildThemeChip(
                              context: context,
                              repo: repo,
                              mode: ThemeMode.dark,
                              label: 'Dark',
                              icon: Icons.dark_mode_rounded,
                              isDark: isDark,
                              cardBorder: cardBorder,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Profile Details Box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, color: Color(0xFF6366F1), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'User Profile Details',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (user.isStudent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: textSubColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: textSubColor, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Read-Only',
                                    style: TextStyle(color: textSubColor, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Divider(color: cardBorder, height: 24),
                      _buildProfileField('Full Name', user.name, Icons.badge_outlined, textColor, textSubColor),
                      const SizedBox(height: 14),
                      _buildProfileField('Email Address', user.email, Icons.email_outlined, textColor, textSubColor),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Registered Hardware Device',
                        user.registeredDeviceId != null
                            ? '${user.deviceModel ?? "Phone"} (${user.registeredDeviceId})'
                            : 'Unbound (Will bind on next login)',
                        Icons.phonelink_lock_outlined,
                        textColor,
                        textSubColor,
                      ),
                      const SizedBox(height: 14),
                      _buildProfileField(
                        'Account Created Date',
                        dateFormat.format(user.createdAt),
                        Icons.calendar_today_outlined,
                        textColor,
                        textSubColor,
                      ),
                      if (user.isStudent) ...[
                        const SizedBox(height: 14),
                        Text(
                          '* Account name and email changes require Admin privileges.',
                          style: TextStyle(color: textSubColor, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Software Version & In-App Updates Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.system_update_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Software Version & Releases',
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Royal Hands ${_currentAppVersion.isNotEmpty ? "v$_currentAppVersion" : "App"} • Connected to GitHub',
                              style: TextStyle(color: textSubColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isCheckingUpdate ? null : _handleManualUpdateCheck,
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                        label: const Text(
                          'Check',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Security & Student Onboarding Guide Card
                if (user.isStudent) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withAlpha(12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security Rules & Student Guide',
                                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Review device binding rules, view limits, and anti-piracy policies.',
                                style: TextStyle(color: textSubColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentOnboardingScreen()),
                            );
                          },
                          icon: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 16),
                          label: const Text(
                            'Open Guide',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 5. Password Change Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_reset_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Change Password',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Divider(color: cardBorder, height: 24),
                      TextField(
                        controller: _currentPasswordCtrl,
                        obscureText: _obscureCurrent,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle: TextStyle(color: textSubColor),
                          prefixIcon: Icon(Icons.key, color: textSubColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                              color: textSubColor,
                            ),
                            onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNew,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(color: textSubColor),
                          prefixIcon: Icon(Icons.lock_outline, color: textSubColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_off : Icons.visibility,
                              color: textSubColor,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: TextStyle(color: textSubColor),
                          prefixIcon: Icon(Icons.lock_outline, color: textSubColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: textSubColor,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isUpdating ? null : _handleChangePassword,
                        icon: _isUpdating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text(
                          'Update Password',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 5. Prominent Log Out Button
                ElevatedButton.icon(
                  onPressed: () => _showLogoutConfirmation(context, repo),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                  label: const Text(
                    'Log Out Account',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeChip({
    required BuildContext context,
    required LmsRepository repo,
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color cardBorder,
  }) {
    final isSelected = repo.themeMode == mode;
    final activeColor = const Color(0xFF6366F1);

    return InkWell(
      onTap: () => repo.setThemeMode(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value, IconData icon, Color textColor, Color textSubColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSubColor, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: textSubColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
