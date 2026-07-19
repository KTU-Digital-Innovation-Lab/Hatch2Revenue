import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'providers/theme_provider.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/lifecycle/lifecycle_screen.dart';
import 'screens/vaccination/vaccination_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/egg_production/egg_production_screen.dart';
import 'screens/mortality/mortality_screen.dart';
import 'screens/financial/financial_screen.dart';
import 'screens/farm_profile/farm_profile_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_colors.dart';
import 'utils/app_feedback.dart';

class PoultryApp extends StatelessWidget {
  const PoultryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BatchProvider()..init()),
        ChangeNotifierProvider(create: (_) => VaccinationProvider()..init()),
        ChangeNotifierProvider(create: (_) => FeedProvider()..init()),
        ChangeNotifierProvider(create: (_) => MortalityProvider()..init()),
        ChangeNotifierProvider(create: (_) => EggProductionProvider()..init()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()..init()),
        ChangeNotifierProvider(create: (_) => QuickActionProvider()),
        ChangeNotifierProvider(create: (_) => FarmProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SyncService()..start()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final dark = themeProvider.isDark;
          return MaterialApp(
            // Re-inflate the tree on theme change so every widget picks
            // up the new AppColors palette.
            key: ValueKey(dark),
            title: 'Hatch2Revenue',
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(dark),
            home: SplashScreen.completed
                ? const MainNavigation()
                : const SplashScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(bool dark) {
    return ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: AppColors.background,
          textTheme: GoogleFonts.interTextTheme(
            (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
          ),
          colorScheme: dark
              ? ColorScheme.dark(
                  primary: AppColors.amber,
                  secondary: AppColors.green,
                  surface: AppColors.surface,
                )
              : ColorScheme.light(
                  primary: AppColors.amber,
                  secondary: AppColors.green,
                  surface: AppColors.surface,
                ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.background,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          drawerTheme: DrawerThemeData(
            backgroundColor: AppColors.surface,
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.border),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surfaceLight,
            labelStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.amber, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            titleTextStyle: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            contentTextStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: GoogleFonts.inter().fontFamily,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.surfaceLight),
            ),
          ),
          useMaterial3: true,
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
  // Survives the re-inflation that happens on theme toggle so the user
  // stays on the same screen.
  static int _lastIndex = 0;
  int _currentIndex = _lastIndex;
  // Tabs the user came from, so the system back button returns to the
  // previous screen instead of exiting the app.
  final List<int> _history = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // When a background sync pulls remote changes, refresh every
    // provider from the local database so the UI shows them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SyncService>().onDataChanged = () async {
        if (!mounted) return;
        await Future.wait([
          context.read<BatchProvider>().reload(),
          context.read<VaccinationProvider>().reload(),
          context.read<FeedProvider>().reload(),
          context.read<EggProductionProvider>().reload(),
          context.read<MortalityProvider>().reload(),
          context.read<FinancialProvider>().reload(),
        ]);
      };
    });
  }

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

  final List<IconData> _icons = const [
    Icons.space_dashboard_outlined,
    Icons.egg_alt, // Batch Lifecycle — overridden by the hen glyph in the tile
    Icons.vaccines_outlined,
    Icons.grass,
    Icons.egg_outlined,
    Icons.monitor_heart_outlined,
    Icons.payments_outlined,
    Icons.agriculture_outlined,
    Icons.insights,
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
    if (index == _currentIndex) return;
    setState(() {
      _history.add(_currentIndex);
      _currentIndex = index;
      _lastIndex = index;
    });
  }

  /// System back: close the drawer, else step back through visited tabs,
  /// else fall back to the dashboard, and only exit the app from there.
  void _handleBack() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    if (_history.isNotEmpty) {
      setState(() {
        _currentIndex = _history.removeLast();
        _lastIndex = _currentIndex;
      });
    } else if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _lastIndex = 0;
      });
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _titles[_currentIndex],
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              tooltip: themeProvider.isDark ? 'Day mode' : 'Night mode',
              icon: Icon(
                themeProvider.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: themeProvider.toggle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
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
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 270,
      child: Column(
        children: [
          // Logo header
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
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/chicken.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hatch2Revenue',
                              style: GoogleFonts.poppins(
                                color: AppColors.amber,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'FARM MANAGER',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
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
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.agriculture_outlined,
                              color: AppColors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profile.farmName,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
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
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
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
                      icon: _icons[idx],
                      iconImage: idx == 1
                          ? const AssetImage('assets/hen_glyph.png')
                          : null,
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              'Hatch2Revenue v1.0.4',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
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
  final IconData icon;
  final String title;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;
  final ImageProvider? iconImage;

  const _DrawerNavTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.iconImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0x12F5A623) // amber ~7% opacity
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isSelected ? AppColors.amber : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              iconImage != null
                  ? ImageIcon(
                      iconImage,
                      size: 18,
                      color: isSelected ? AppColors.amber : AppColors.textSecondary,
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color: isSelected ? AppColors.amber : AppColors.textSecondary,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isSelected ? AppColors.amber : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    style: GoogleFonts.inter(
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