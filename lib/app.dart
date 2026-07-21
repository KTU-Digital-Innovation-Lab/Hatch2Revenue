import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/batch_provider.dart';
import 'providers/vaccination_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/mortality_provider.dart';
import 'providers/egg_production_provider.dart';
import 'providers/egg_sales_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/quick_action_provider.dart';
import 'providers/farm_profile_provider.dart';
import 'providers/settings_provider.dart';
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
import 'screens/settings/settings_screen.dart';
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
        ChangeNotifierProvider(create: (_) => EggSalesProvider()..init()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()..init()),
        ChangeNotifierProvider(create: (_) => QuickActionProvider()),
        ChangeNotifierProvider(create: (_) => FarmProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SyncService()..start()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settings, _) {
          final dark = themeProvider.isDark;
          return MaterialApp(
            // Re-inflate the tree whenever the palette changes (theme,
            // colour-vision mode, or contrast) so every widget picks up
            // the new AppColors values.
            key: ValueKey('$dark-${settings.vision.index}-${settings.highContrast}'),
            title: 'Hatch2Revenue',
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(dark),
            // Farmer-chosen text size applies app-wide.
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: settings.textScale,
              maxScaleFactor: settings.textScale,
              child: child!,
            ),
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
              borderSide: BorderSide(color: AppColors.amber, width: 2),
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
  /// The farmer's chosen start-up screen is applied once per app launch;
  /// after that _lastIndex preserves where they were across rebuilds.
  static bool _startTabApplied = false;
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
      if (!_startTabApplied) {
        _startTabApplied = true;
        final start = context.read<SettingsProvider>().startTab;
        if (start != _currentIndex && start >= 0 && start < _screens.length) {
          setState(() {
            _currentIndex = start;
            _lastIndex = start;
          });
        }
      }
      context.read<SyncService>().onDataChanged = () async {
        if (!mounted) return;
        await Future.wait([
          context.read<BatchProvider>().reload(),
          context.read<VaccinationProvider>().reload(),
          context.read<FeedProvider>().reload(),
          context.read<EggProductionProvider>().reload(),
          context.read<EggSalesProvider>().reload(),
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

  // ── Bottom bar: the five modules a farmer touches daily. Everything
  // else lives one tap away in More, so the whole app stays reachable
  // with a thumb.
  static const List<int> _barTabs = [0, 1, 4, 3]; // Home, Batches, Eggs, Feed
  static const List<String> _barLabels = ['Home', 'Batches', 'Eggs', 'Feed'];
  static const List<IconData> _barIcons = [
    Icons.space_dashboard_outlined,
    Icons.pets,
    Icons.egg_outlined,
    Icons.grass,
  ];

  // Screens reachable from the More sheet.
  static const List<int> _moreTabs = [2, 5, 6, 8, 7];

  bool get _onMoreScreen => !_barTabs.contains(_currentIndex);

  void _openMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('All modules',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 10),
              Consumer<VaccinationProvider>(
                builder: (context, vacc, _) => Column(
                  children: [
                    for (final i in _moreTabs)
                      _moreTile(
                        ctx,
                        icon: _icons[i],
                        title: _titles[i],
                        badge: i == 2 && vacc.overdueCount > 0
                            ? vacc.overdueCount
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _setIndex(i);
                        },
                      ),
                    _moreTile(
                      ctx,
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext ctx,
      {required IconData icon,
      required String title,
      int? badge,
      required VoidCallback onTap}) {
    final selected = _titles.contains(title) &&
        _currentIndex == _titles.indexOf(title);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.amber : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                    color: selected ? AppColors.amber : AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
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
        // No app bar: every screen already shows its own name, and the
        // freed height keeps content within thumb reach.
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final overdue = context.watch<VaccinationProvider>().overdueCount;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _barTabs.length; i++)
                _barItem(
                  icon: _barIcons[i],
                  label: _barLabels[i],
                  selected: _currentIndex == _barTabs[i],
                  onTap: () => _setIndex(_barTabs[i]),
                ),
              _barItem(
                icon: Icons.menu,
                label: 'More',
                selected: _onMoreScreen,
                badge: overdue > 0 ? overdue : null,
                onTap: _openMore,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? badge,
  }) {
    final color = selected ? AppColors.amber : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.amber.withValues(alpha: 0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                if (badge != null)
                  Positioned(
                    right: 6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                      child: Text('$badge',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}
