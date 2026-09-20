import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OnboardingSlide {
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final String title;
  final String description;
  final String alertTitle;
  final String alertMessage;
  final IconData alertIcon;
  final Color alertBorderColor;
  final Color alertBgColor;
  final String lottieAsset;

  const OnboardingSlide({
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.title,
    required this.description,
    required this.alertTitle,
    required this.alertMessage,
    required this.alertIcon,
    required this.alertBorderColor,
    required this.alertBgColor,
    required this.lottieAsset,
  });
}

class StudentOnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinish;

  const StudentOnboardingScreen({super.key, this.onFinish});

  @override
  State<StudentOnboardingScreen> createState() => _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = const [
    // Slide 1: Device Binding Warning
    OnboardingSlide(
      badgeText: '⚠️ DEVICE SECURITY POLICY',
      badgeColor: Color(0xFFEF4444),
      badgeBg: Color(0x22EF4444),
      title: 'One Student Account,\nOne Registered Device',
      description:
          'Your LMS account is cryptographically bound to this physical mobile hardware. Logging in from another unregistered device will be blocked automatically.',
      alertTitle: 'Hardware Binding Warning:',
      alertMessage:
          'Device transfer requests require valid reason verification and Administrator approval before access is restored.',
      alertIcon: Icons.phonelink_lock_rounded,
      alertBorderColor: Color(0x66EF4444),
      alertBgColor: Color(0x1DEF4444),
      lottieAsset: 'assets/animation/Password Authentication.json',
    ),

    // Slide 2: Anti-Screen Recording Warning
    OnboardingSlide(
      badgeText: '🛡️ ANTI-PIRACY PROTECTION',
      badgeColor: Color(0xFFF59E0B),
      badgeBg: Color(0x22F59E0B),
      title: 'Anti-Screen Recording &\nCapture Active',
      description:
          'Screen recording apps, background video capture software, and HDMI screen mirroring are strictly prohibited and actively detected by security services.',
      alertTitle: 'Protection Notice:',
      alertMessage:
          'Detected screen recording software automatically pauses video playback and logs account details to prevent copyright infringement.',
      alertIcon: Icons.videocam_off_rounded,
      alertBorderColor: Color(0x66F59E0B),
      alertBgColor: Color(0x1DF59E0B),
      lottieAsset: 'assets/animation/Security System.json',
    ),

    // Slide 3: Lesson View Limits Guide
    OnboardingSlide(
      badgeText: '📊 VIEW LIMIT ALLOWANCES',
      badgeColor: Color(0xFF8B5CF6),
      badgeBg: Color(0x228B5CF6),
      title: 'Track Your Lesson\nView Allowances',
      description:
          'Each recorded class has a fixed number of view attempts assigned by your instructor. Watch sessions monitor completion to track your learning progress.',
      alertTitle: 'Usage Recommendation:',
      alertMessage:
          'Ensure continuous watching to avoid consuming extra view allowances. Contact your Administrator if view limit extensions are needed.',
      alertIcon: Icons.timelapse_rounded,
      alertBorderColor: Color(0x668B5CF6),
      alertBgColor: Color(0x1D8B5CF6),
      lottieAsset: 'assets/animation/dashboard_animation.json',
    ),

    // Slide 4: Live Classroom & Recorded Lectures Guide
    OnboardingSlide(
      badgeText: '🚀 READY TO LEARN',
      badgeColor: Color(0xFF10B981),
      badgeBg: Color(0x2210B981),
      title: 'Live Classrooms &\nRecorded Video Portal',
      description:
          'Join real-time interactive streaming classrooms directly inside the secure player and explore recorded course materials anytime.',
      alertTitle: 'Student Welcome:',
      alertMessage:
          'You are now fully aligned with security rules. Tap below to access your student portal dashboard.',
      alertIcon: Icons.school_rounded,
      alertBorderColor: Color(0x6610B981),
      alertBgColor: Color(0x1D10B981),
      lottieAsset: 'assets/animation/Online Learning.json',
    ),
  ];

  void _onNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    if (widget.onFinish != null) {
      widget.onFinish!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Skip Button & Step Indicator Text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      'STEP ${_currentIndex + 1} OF ${_slides.length}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Skip Guide',
                      style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Main PageView Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lottie Animation Container
                        Center(
                          child: Container(
                            height: 230,
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Lottie.asset(
                              slide.lottieAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.security, size: 90, color: Color(0xFF6366F1)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: slide.badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: slide.badgeColor.withAlpha(100)),
                          ),
                          child: Text(
                            slide.badgeText,
                            style: TextStyle(
                              color: slide.badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Slide Title
                        Text(
                          slide.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Text(
                          slide.description,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Alert / Warning / Tip Container Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: slide.alertBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: slide.alertBorderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(slide.alertIcon, color: slide.badgeColor, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slide.alertTitle,
                                      style: TextStyle(
                                        color: slide.badgeColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slide.alertMessage,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Footer (Dots & Action Button)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Animated Dots Indicator
                  Row(
                    children: List.generate(_slides.length, (idx) {
                      final isSelected = idx == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected ? _slides[_currentIndex].badgeColor : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Finish Button
                  ElevatedButton.icon(
                    onPressed: _onNext,
                    icon: Icon(
                      _currentIndex == _slides.length - 1 ? Icons.check_circle : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      _currentIndex == _slides.length - 1 ? 'Get Started' : 'Next Step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _slides[_currentIndex].badgeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                      shadowColor: _slides[_currentIndex].badgeColor.withAlpha(90),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
