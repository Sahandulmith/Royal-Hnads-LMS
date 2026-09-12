import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/services/lms_repository.dart';
import 'core/services/security_service.dart';
import 'core/services/update_service.dart';
import 'screens/widgets/update_dialog.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LmsRepository(),
      child: const SecureLmsApp(),
    ),
  );
}

class SecureLmsApp extends StatefulWidget {
  const SecureLmsApp({super.key});

  @override
  State<SecureLmsApp> createState() => _SecureLmsAppState();
}

class _SecureLmsAppState extends State<SecureLmsApp> with WidgetsBindingObserver {
  bool _isAppPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SecurityService.enableSecureScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      setState(() => _isAppPaused = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _isAppPaused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);

    return MaterialApp(
      title: 'Royal Hands',
      debugShowCheckedModeBanner: false,
      themeMode: repo.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF6366F1),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
        ),
        cardColor: Colors.white,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF8B5CF6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF6366F1),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF8FAFC),
        ),
        cardColor: const Color(0xFF1E293B),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return SecurityService.wrapWithPrivacyShield(
          context: context,
          isAppPaused: _isAppPaused,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const RootRoleGuard(),
    );
  }
}

class RootRoleGuard extends StatefulWidget {
  const RootRoleGuard({super.key});

  @override
  State<RootRoleGuard> createState() => _RootRoleGuardState();
}

class _RootRoleGuardState extends State<RootRoleGuard> {
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _triggerAutoUpdateCheck();
  }

  void _triggerAutoUpdateCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasCheckedUpdate) return;
      _hasCheckedUpdate = true;

      // Small delay to ensure initial route is mounted
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      final updateInfo = await UpdateService.checkForUpdates(isManualCheck: false);
      if (updateInfo.hasUpdate && mounted) {
        UpdateAvailableDialog.show(context, updateInfo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);

    if (repo.isCheckingSession) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/royal hands.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 40, color: Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }

    if (!repo.isAuthenticated) {
      return const LoginScreen();
    }

    if (repo.isAdmin) {
      return const AdminDashboard();
    }

    return const StudentDashboard();
  }
}
