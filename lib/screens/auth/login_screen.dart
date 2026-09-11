import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/lms_repository.dart';
import '../../core/services/device_service.dart';
import 'device_request_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'student1@lms.com');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  bool _isLoading = false;
  DeviceInformation? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _loadDeviceDetails();
  }

  Future<void> _loadDeviceDetails() async {
    final details = await DeviceService.getDeviceDetails();
    if (mounted) {
      setState(() => _deviceInfo = details);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter your email and password.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    final repo = Provider.of<LmsRepository>(context, listen: false);
    final result = await repo.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showSnackBar('Welcome back, ${result.user?.name}!', Colors.greenAccent);
    } else if (result.requiresDeviceApproval && result.user != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeviceRequestDialog(user: result.user!),
      );
    } else {
      _showSnackBar(result.errorMessage ?? 'Login failed.', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _setPresetAccount(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = 'password123';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Secure LMS Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recorded Lesson Streaming & Access Control',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Device Fingerprint Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, color: Color(0xFF10B981), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Device Binding Security Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deviceInfo != null
                                  ? '${_deviceInfo!.model} • ${_deviceInfo!.osVersion}'
                                  : 'Detecting device Hardware ID...',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Login Form
                const Text(
                  'Email / Username',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
                    hintText: 'Enter student or admin email',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Password',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: 'Enter password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Secure Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),

                const SizedBox(height: 36),

                // Quick Demo Account Selection Shortcuts
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withAlpha(150),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.touch_app_outlined, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Quick Demo Accounts:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAccountChip('Student 1 (Bound)', 'student1@lms.com', Colors.indigoAccent),
                          _buildAccountChip('Student 2 (New Device)', 'student2@lms.com', Colors.tealAccent),
                          _buildAccountChip('Student 3 (Inactive)', 'student3@lms.com', Colors.redAccent),
                          _buildAccountChip('Admin Dashboard', 'admin@lms.com', Colors.purpleAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountChip(String label, String email, Color accentColor) {
    return InkWell(
      onTap: () => _setPresetAccount(email),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withAlpha(80)),
        ),
        child: Text(
          label,
          style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
