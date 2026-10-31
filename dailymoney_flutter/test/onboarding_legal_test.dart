import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/app.dart';
import 'package:dailymoney/providers/capture_provider.dart';
import 'package:dailymoney/providers/expected_income_provider.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/security_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/legal_content.dart';
import 'package:dailymoney/services/storage_service.dart';

class TestApp {
  TestApp({
    required this.storage,
    required this.settings,
    required this.transactions,
    required this.upcoming,
    required this.goals,
    required this.capture,
    required this.security,
    required this.expected,
    required this.shared,
  });

  final StorageService storage;
  final SettingsProvider settings;
  final TransactionsProvider transactions;
  final UpcomingProvider upcoming;
  final GoalsProvider goals;
  final CaptureProvider capture;
  final SecurityProvider security;
  final ExpectedIncomeProvider expected;
  final SharedProvider shared;

  Widget widget() {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: transactions),
        ChangeNotifierProvider.value(value: upcoming),
        ChangeNotifierProvider.value(value: goals),
        ChangeNotifierProvider.value(value: capture),
        ChangeNotifierProvider.value(value: security),
        ChangeNotifierProvider.value(value: expected),
        ChangeNotifierProvider.value(value: shared),
      ],
      child: const DailyMoneyApp(),
    );
  }
}

Future<TestApp> buildApp({bool dismissWelcome = true}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final settings = SettingsProvider(storage);
  await settings.load();
  if (dismissWelcome) await settings.dismissWelcome();
  final transactions = TransactionsProvider(storage);
  await transactions.load();
  final upcoming = UpcomingProvider(storage);
  await upcoming.load();
  final goals = GoalsProvider(storage);
  await goals.load();
  final capture = CaptureProvider(storage);
  await capture.load();
  final security = SecurityProvider(storage);
  await security.load();
  final expected = ExpectedIncomeProvider(storage);
  await expected.load();
  final shared = SharedProvider(storage);
  await shared.load();
  return TestApp(
    storage: storage,
    settings: settings,
    transactions: transactions,
    upcoming: upcoming,
    goals: goals,
    capture: capture,
    security: security,
    expected: expected,
    shared: shared,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('welcome and policy acceptance', () {
    testWidgets('first run requires an explicit policy acceptance', (
      tester,
    ) async {
      useTallPhone(tester);
      final app = await buildApp(dismissWelcome: false);
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to DailyMoney!'), findsOneWidget);
      expect(app.settings.hasAcceptedCurrentPolicies, isFalse);
      expect(app.settings.welcomeSeen, isFalse);

      final tourButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Take a quick tour'),
      );
      expect(tourButton.onPressed, isNull);

      final checkboxes = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(checkboxes.length, 2);
      // Neither the sample-data choice nor the legal acceptance is selected.
      expect(checkboxes.every((c) => c.value == false), isTrue);

      await tester.tap(find.textContaining('I have read and agree'));
      await tester.pump();
      expect(app.settings.hasAcceptedCurrentPolicies, isFalse);

      await tester.tap(find.text('Explore myself'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('DailyMoney'),
        ),
        findsOneWidget,
      );
      expect(app.settings.welcomeSeen, isTrue);
      expect(app.settings.hasAcceptedCurrentPolicies, isTrue);
      expect(app.settings.legalAcceptedVersion, kLegalVersion);
      expect(app.settings.legalAcceptedAt, isNotNull);
      expect(app.settings.tutorialInProgress, isFalse);
      // Sample data is opt-in and was left unchecked.
      expect(app.transactions.count, 0);
    });

    testWidgets('sample data is opt-in and generated on request',
        (tester) async {
      useTallPhone(tester);
      final app = await buildApp(dismissWelcome: false);
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('I have read and agree'));
      await tester.tap(find.text('Start with sample data'));
      await tester.pump();
      await tester.tap(find.text('Explore myself'));
      await tester.pumpAndSettle();

      expect(app.transactions.count, greaterThan(50));
      expect(app.upcoming.count, greaterThan(0));
      expect(app.goals.count, greaterThan(0));
      expect(app.settings.welcomeSeen, isTrue);
    });
  });

  group('guided tour', () {
    testWidgets('tour is skippable and does not create records',
        (tester) async {
      useTallPhone(tester);
      final app = await buildApp();
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();
      final before = app.transactions.count;

      await app.settings.replayTutorial();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Your money at a glance'), findsOneWidget);
      expect(find.text('1 / 10'), findsOneWidget);
      expect(find.text('Skip tour'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("Today's spending money"), findsOneWidget);
      expect(find.text('2 / 10'), findsOneWidget);

      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();

      expect(app.settings.tutorialInProgress, isFalse);
      expect(app.settings.tutorialSkipped, isTrue);
      expect(app.transactions.count, before);
      expect(find.text('Your money at a glance'), findsNothing);
    });

    testWidgets('completion card returns to the app', (tester) async {
      useTallPhone(tester);
      final app = await buildApp();
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();

      await app.settings.replayTutorial();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your money at a glance'), findsOneWidget);

      await app.settings.markTutorialCompleted();
      await tester.pump();
      expect(find.text("You're ready!"), findsOneWidget);

      await tester.tap(find.text('Start using DailyMoney'));
      await tester.pumpAndSettle();

      expect(app.settings.tutorialCompleted, isTrue);
      expect(app.settings.tutorialInProgress, isFalse);
      expect(app.settings.tutorialCompletedAt, isNotNull);
      expect(find.text("You're ready!"), findsNothing);
    });
  });

  group('legal, consent and reset persistence', () {
    test('policy acceptance and tour progress survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final settings = SettingsProvider(storage);
      await settings.load();

      await settings.acceptPolicies(now: DateTime(2026, 10, 29, 10, 30));
      await settings.startTutorial();
      await settings.setTutorialStep(4);
      await settings.markTutorialCompleted(now: DateTime(2026, 10, 29, 11));

      final reloaded = SettingsProvider(storage);
      await reloaded.load();
      expect(reloaded.hasAcceptedCurrentPolicies, isTrue);
      expect(reloaded.legalAcceptedVersion, kLegalVersion);
      expect(reloaded.legalAcceptedAt, startsWith('2026-10-29'));
      expect(reloaded.tutorialCompleted, isTrue);
      expect(reloaded.tutorialStep, 999);
      expect(reloaded.tutorialCompletedAt, startsWith('2026-10-29'));
    });

    test('consent is purpose-specific and timestamped', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final settings = SettingsProvider(storage);
      await settings.load();

      expect(settings.notificationsConsent, isFalse);
      expect(settings.autoCaptureConsent, isFalse);

      await settings.setNotificationsConsent(true);
      expect(settings.notificationsConsent, isTrue);
      expect(settings.notificationsConsentAt, isNotNull);
      expect(settings.notificationsConsentVersion, kConsentVersion);
      expect(settings.autoCaptureConsent, isFalse);
      final prefs = await SharedPreferences.getInstance();
      // The native listener gates review prompts on this mirrored flag.
      expect(prefs.getBool('dm.notify.prompt.v1'), isTrue);

      await settings.setAutoCapture(true);
      expect(settings.autoCaptureConsent, isTrue);
      expect(settings.autoCaptureConsentAt, isNotNull);
      expect(settings.autoCaptureConsentVersion, kConsentVersion);

      await settings.setMorningBriefing(true);
      await settings.setNightSummary(true);
      await settings.setBudgetAlerts(true);
      await settings.setNotificationsConsent(false);
      expect(settings.notificationsConsent, isFalse);
      expect(settings.notificationsConsentAt, isNull);
      expect(settings.morningBriefing, isFalse);
      expect(settings.nightSummary, isFalse);
      expect(settings.budgetAlerts, isFalse);
      expect(prefs.getBool('dm.notify.prompt.v1'), isFalse);

      await settings.setAutoCapture(false);
      expect(settings.autoCaptureConsent, isFalse);
      expect(settings.autoCaptureConsentAt, isNull);
    });

    test('upgrades treat an existing install as welcome-seen', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      // An older install has the seeded flag but no welcomeSeen field.
      await storage.saveSettings({'seeded': true});

      final reloaded = SettingsProvider(storage);
      await reloaded.load();
      expect(reloaded.seeded, isTrue);
      expect(reloaded.welcomeSeen, isTrue);
    });

    test('a full reset clears onboarding and legal state, keeps seeded',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final settings = SettingsProvider(storage);
      await settings.load();
      await settings.acceptPolicies();
      await settings.startTutorial();
      await settings.setNotificationsConsent(true);

      await settings.resetToDefaults();

      expect(settings.seeded, isTrue);
      expect(settings.welcomeSeen, isFalse);
      expect(settings.hasAcceptedCurrentPolicies, isFalse);
      expect(settings.legalAcceptedAt, isNull);
      expect(settings.notificationsConsent, isFalse);
      expect(settings.tutorialInProgress, isFalse);
      expect(settings.tutorialCompleted, isFalse);
    });
  });
}
