import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'providers/capture_provider.dart';
import 'providers/expected_income_provider.dart';
import 'providers/goals_provider.dart';
import 'providers/security_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shared_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/upcoming_provider.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_edit_sheet.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/briefings.dart';
import 'services/capture_service.dart';
import 'services/money_plan.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'theme.dart';
import 'widgets/tutorial_overlay.dart';

class DailyMoneyApp extends StatelessWidget {
  const DailyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'DailyMoney',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          builder: (context, child) =>
              LockGate(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        );
      },
    );
  }
}

/// Shows the first-run welcome before the working shell. Existing installs
/// migrate with `welcomeSeen = true`, so an upgrade does not look like a reset.
class WelcomeGate extends StatelessWidget {
  const WelcomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final welcomeSeen = context.watch<SettingsProvider>().welcomeSeen;
    return welcomeSeen ? const RootShell() : const WelcomeScreen();
  }
}

/// Shows the lock screen over the whole app — including any open dialogs —
/// while preserving the shell underneath so unlocking returns exactly where
/// the user left off.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<SecurityProvider>().locked;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeFocus(
            excluding: locked,
            child: TickerMode(
              enabled: !locked,
              child: Offstage(offstage: locked, child: child),
            ),
          ),
        ),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// Bottom-nav shell; keeps each tab's state via IndexedStack.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _index = 0;
  String? _notificationSignature;
  DateTime? _pausedAt;
  final TutorialAnchors _tour = TutorialAnchors();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final security = context.read<SecurityProvider>();

    if (state == AppLifecycleState.paused) {
      // Auto-lock when the app leaves the foreground. A zero-second setting
      // locks immediately; any other value starts the countdown.
      if (security.pinEnabled && !security.locked) {
        if (security.autoLockSeconds == 0) {
          security.lock();
        } else {
          _pausedAt = DateTime.now();
        }
      }
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    if (security.pinEnabled && !security.locked && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!).inSeconds;
      if (away >= security.autoLockSeconds) security.lock();
    }
    _pausedAt = null;

    // A resume may be the first frame of a new day (and the first chance to
    // refresh briefings after a reboot), so recompute the allowance and
    // reschedule even if the numbers happen to match the cached signature.
    _notificationSignature = null;
    if (mounted) setState(() {});
    _scheduleNotifications();
    _refreshCapture();
  }

  Future<void> _refreshCapture() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    await context.read<CaptureProvider>().refresh(
          acceptNative: settings.autoCapture,
        );
    if (!mounted) return;
    if (settings.autoCapture && !await CaptureService.hasAccess()) {
      await settings.setAutoCapture(false);
    }
  }

  Future<void> _bootstrapNotifications() async {
    if (!mounted || !NotificationService.isReady) return;
    // Permission is never requested at startup. The user turns a notification
    // feature on explicitly in Settings or Consent and permissions, and that
    // flow requests the Android permission.
    _notificationSignature = null;
    _scheduleNotifications();
  }

  void _scheduleNotifications() {
    if (!mounted || !NotificationService.isReady) return;
    final settings = context.read<SettingsProvider>();
    final txs = context.read<TransactionsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final expected = context.read<ExpectedIncomeProvider>();
    final shared = context.read<SharedProvider>();
    final snapshot = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );

    final signature = [
      settings.currencyCode,
      settings.monthlyBudget,
      settings.notificationsConsent,
      settings.morningBriefing,
      settings.morningMinutes,
      settings.nightSummary,
      settings.nightMinutes,
      settings.userName,
      settings.allowancePolicy.name,
      settings.moneyProtection,
      settings.emergencyBuffer,
      settings.recoveryActive,
      settings.recoveryDays,
      settings.recoveryDailyCut,
      txs.count,
      txs.balance,
      snapshot.allowance,
      snapshot.spentToday,
      snapshot.remainingToday,
      snapshot.monthlyLeft,
      upcoming.count,
      upcoming.reservedForMonth(DateTime.now()),
      goals.count,
      goals.totalRemaining,
      expected.pending.length,
      expected.pendingTotal,
      shared.owedToMe,
      shared.iOwe,
    ].join('|');
    if (signature == _notificationSignature) return;
    _notificationSignature = signature;

    final morning = Briefings.morning(
      settings: settings,
      snapshot: snapshot,
      upcoming: upcoming,
      expected: expected,
    );
    final night = Briefings.night(
      settings: settings,
      snapshot: snapshot,
      upcoming: upcoming,
      shared: shared,
      expected: expected,
    );

    NotificationService.refreshBriefings(
      morningEnabled: settings.morningBriefing,
      morningTime: settings.morningTime,
      morningTitle: morning.title,
      morningBody: morning.body,
      nightEnabled: settings.nightSummary,
      nightTime: settings.nightTime,
      nightTitle: night.title,
      nightBody: night.body,
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddEditSheet(),
    );
  }

  /// The tour asks for a tab from inside a build/didChangeDependencies cycle,
  /// so the actual navigation is deferred to the next frame.
  void _tourNavigateTab(int index) {
    if (!mounted || index == _index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index == _index) return;
      setState(() => _index = index);
    });
  }

  void _goToTab(int index) {
    if (!mounted || index == _index) return;
    SoundService.instance.nav();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild (and refresh notification content) when budget inputs change.
    final settings = context.watch<SettingsProvider>();
    context.watch<TransactionsProvider>();
    context.watch<UpcomingProvider>();
    context.watch<GoalsProvider>();
    context.watch<ExpectedIncomeProvider>();
    context.watch<SharedProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNotifications();
    });

    final shell = Scaffold(
      appBar: null,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onSeeAll: () => _goToTab(2),
            onOpenSettings: () => _goToTab(3),
            overviewAnchor: _tour.overview,
            allowanceAnchor: _tour.allowance,
          ),
          StatsScreen(
            categoriesAnchor: _tour.categories,
            insightsAnchor: _tour.insights,
          ),
          const TransactionsScreen(),
          SettingsScreen(
            budgetAnchor: _tour.budget,
            whatIfAnchor: _tour.whatIf,
            nightSummaryAnchor: _tour.nightSummary,
            privacyAnchor: _tour.privacy,
            dataAnchor: _tour.data,
          ),
        ],
      ),
      // Adding a transaction makes no sense inside Settings, and the floating
      // button would cover the privacy notes there.
      floatingActionButton: _index == 3
          ? null
          : KeyedSubtree(
              key: _tour.addButton,
              child: FloatingActionButton(
                onPressed: _openAddSheet,
                tooltip: 'Add transaction',
                child: const Icon(LucideIcons.plus, size: 26),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            selectedIcon: Icon(LucideIcons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.pieChart),
            selectedIcon: Icon(LucideIcons.pieChart),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.receipt),
            selectedIcon: Icon(LucideIcons.receipt),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            selectedIcon: Icon(LucideIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );

    // The tour is layered over the whole shell — including the navigation bar
    // and the floating button — so its spotlight can point at real controls.
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: shell),
          if (settings.tutorialInProgress)
            Positioned.fill(
              // The tour covers the shell, so its scrim must also hide the
              // controls underneath from screen readers.
              child: BlockSemantics(
                child: TutorialOverlay(
                  anchors: _tour,
                  stepIndex: settings.tutorialStep,
                  onNavigateTab: _tourNavigateTab,
                  onOpenAddSheet: _openAddSheet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
