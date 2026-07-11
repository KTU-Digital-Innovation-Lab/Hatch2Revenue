import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';
import '../utils/app_colors.dart';

/// Launch screen — centered rooster + wordmark on an agricultural
/// gradient, a slim progress bar, then a smooth fade into the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Shown only once per app launch — a theme toggle re-inflates the
  /// tree, and this flag stops the splash replaying on every switch.
  static bool completed = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void initState() {
    super.initState();
    // Hold briefly so init (DB, notifications, sync check) settles,
    // then fade into the main app.
    Future.delayed(const Duration(milliseconds: 2400), _goToApp);
  }

  void _goToApp() {
    if (!mounted) return;
    SplashScreen.completed = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => const MainNavigation(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Warm, agricultural gradient tuned to the FarmNest green palette.
    final dark = AppColors.isDark;
    final gradient = dark
        ? [const Color(0xFF10160F), const Color(0xFF1A231A), const Color(0xFF24301F)]
        : [const Color(0xFFF7FAF7), const Color(0xFFEAF3E7), const Color(0xFFDDEFD6)];

    final logoIn = CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
    final fadeIn = CurvedAnimation(parent: _entrance, curve: Curves.easeIn);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: logoIn,
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.25),
                                blurRadius: 34,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Image.asset('assets/chicken.png',
                              fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 26),
                      FadeTransition(
                        opacity: fadeIn,
                        child: Column(
                          children: [
                            Text(
                              'Hatch2Revenue',
                              style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'From hatch to harvest.',
                              style: GoogleFonts.inter(
                                color: AppColors.amber,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Slim progress bar reassures the farmer things are loading.
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 60, right: 60),
                child: FadeTransition(
                  opacity: fadeIn,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) => LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 4,
                        backgroundColor:
                            AppColors.textSecondary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(AppColors.amber),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
