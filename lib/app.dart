import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'providers/batch_provider.dart';
import 'providers/vaccination_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/mortality_provider.dart';
import 'providers/egg_production_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/quick_action_provider.dart';
import 'providers/farm_profile_provider.dart';
import 'screens/home_screen.dart';
import 'screens/lifecycle/lifecycle_screen.dart';
import 'screens/vaccination/vaccination_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/egg_production/egg_production_screen.dart';
import 'screens/mortality/mortality_screen.dart';
import 'screens/financial/financial_screen.dart';
import 'screens/farm_profile/farm_profile_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'utils/app_colors.dart';

class PoultryApp extends StatelessWidget {
  const PoultryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => VaccinationProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => MortalityProvider()),
        ChangeNotifierProvider(create: (_) => EggProductionProvider()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()),
        ChangeNotifierProvider(create: (_) => QuickActionProvider()),
        ChangeNotifierProvider(create: (_) => FarmProfileProvider()),
      ],
      child: MaterialApp(
        title: 'Hatch2Revenue',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.light().textTheme.apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
          ),
          colorScheme: const ColorScheme.light(
            primary: AppColors.green,
            secondary: AppColors.amber,
            surface: AppColors.surface,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: AppColors.surface,
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surfaceLight,
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.green, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            titleTextStyle: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            contentTextStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            contentTextStyle: GoogleFonts.poppins(color: Colors.white),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          dropdownMenuTheme: const DropdownMenuThemeData(
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.surfaceLight),
            ),
          ),
          useMaterial3: true,
        ),
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();

  static void navigateTo(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainNavigationState>()?._setIndex(index);
  }
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [
    HomeScreen(),
    LifecycleScreen(),
    VaccinationScreen(),
    FeedScreen(),
    EggProductionScreen(),
    MortalityScreen(),
    FinancialScreen(),
    FarmProfileScreen(),
    AnalyticsScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Batch Lifecycle',
    'Vaccination',
    'Feed Monitor',
    'Egg Production',
    'Mortality Log',
    'Financials',
    'Farm Profile',
    'Analytics',
  ];

  final List<String> _emojis = const [
    '🏠',
    '🐣',
    '💉',
    '🌾',
    '🥚',
    '⚠️',
    '💰',
    '🏡',
    '📊',
  ];

  // Nav section structure: null = section header label, int = screen index
  static const List<_NavItem> _navItems = [
    _NavItem(sectionLabel: 'MAIN'),
    _NavItem(index: 0),
    _NavItem(sectionLabel: 'OPERATIONS'),
    _NavItem(index: 1),
    _NavItem(index: 2),
    _NavItem(index: 3),
    _NavItem(index: 4),
    _NavItem(index: 5),
    _NavItem(index: 6),
    _NavItem(sectionLabel: 'ANALYTICS'),
    _NavItem(index: 8),
    _NavItem(sectionLabel: 'SYSTEM'),
    _NavItem(index: 7),
  ];

  void _setIndex(int index) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen farm background image
        Positioned.fill(
          child: Image.asset(
            'assets/farm_bg.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Gradient overlay — darker at edges, lighter in center to keep image visible
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD9142A14), // deep forest green 85%
                  Color(0xBB1B2B1C), // dark green 73%
                ],
              ),
            ),
          ),
        ),
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xEE2E7D32), // dark green 93%
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: Colors.white24),
            ),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text(
              _titles[_currentIndex],
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          drawer: _buildDrawer(context),
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 270,
      child: Column(
        children: [
          // Logo header — amber background matching AppBar
          Consumer<FarmProfileProvider>(
            builder: (context, farmProvider, _) {
              final profile = farmProvider.profile;
              return Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('🐓', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hatch2Revenue',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'FARM MANAGER',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (profile.farmName.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.agriculture_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profile.farmName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          // Nav items
          Expanded(
            child: Consumer<VaccinationProvider>(
              builder: (context, vaccProvider, _) {
                final overdueCount = vaccProvider.overdueCount;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _navItems.length,
                  itemBuilder: (context, i) {
                    final item = _navItems[i];
                    if (item.sectionLabel != null) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          top: 16,
                          bottom: 4,
                        ),
                        child: Text(
                          item.sectionLabel!,
                          style: GoogleFonts.poppins(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      );
                    }
                    final idx = item.index!;
                    final isSelected = _currentIndex == idx;
                    final showBadge = idx == 2 && overdueCount > 0;
                    return _DrawerNavTile(
                      emoji: _emojis[idx],
                      title: _titles[idx],
                      isSelected: isSelected,
                      badge: showBadge ? overdueCount : null,
                      onTap: () => _setIndex(idx),
                    );
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              'Hatch2Revenue v1.0.0',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String? sectionLabel;
  final int? index;
  const _NavItem({this.sectionLabel, this.index});
}

class _DrawerNavTile extends StatelessWidget {
  final String emoji;
  final String title;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.emoji,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.green.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isSelected ? AppColors.green : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
