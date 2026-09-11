import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/lms_repository.dart';
import 'core/services/security_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'Secure LMS Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF6366F1),
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

class RootRoleGuard extends StatelessWidget {
  const RootRoleGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LmsRepository>(context);

    if (!repo.isAuthenticated) {
      return const LoginScreen();
    }

    if (repo.isAdmin) {
      return const AdminDashboard();
    }

    return const StudentDashboard();
  }
}
