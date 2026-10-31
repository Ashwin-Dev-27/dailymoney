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
import 'package:dailymoney/screens/help_centre_screen.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/services/user_guide_content.dart';
import 'package:dailymoney/theme.dart';

Future<SettingsProvider> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final settings = SettingsProvider(storage);
  await settings.load();
  await settings.dismissWelcome();
  return settings;
}

Widget _simpleApp(SettingsProvider settings, Widget home) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: home,
    ),
  );
}

Widget _launcher(SettingsProvider settings) {
  return _simpleApp(
    settings,
    Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HelpCentreScreen(),
              ),
            ),
            child: const Text('Open help'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guide content', () {
    test('has twelve sequential chapters with complete sections', () {
      expect(kGuideChapters.length, 12);
      expect(
        kGuideChapters.map((chapter) => chapter.number).toList(),
        List.generate(12, (i) => i + 1),
      );
      expect(
        kGuideChapters.map((chapter) => chapter.id).toSet().length,
        kGuideChapters.length,
      );

      for (final chapter in kGuideChapters) {
        expect(chapter.title, isNotEmpty);
        expect(chapter.summary, isNotEmpty);
        expect(chapter.what, isNotEmpty);
        expect(chapter.why, isNotEmpty);
        expect(chapter.where, isNotEmpty);
        expect(chapter.steps.length, greaterThanOrEqualTo(3));
        expect(chapter.example, isNotEmpty);
        expect(chapter.mistakes.length, greaterThanOrEqualTo(2));
        for (final step in chapter.steps) {
          expect(step, isNotEmpty);
        }
        for (final mistake in chapter.mistakes) {
          expect(mistake.problem, isNotEmpty);
          expect(mistake.fix, isNotEmpty);
        }
      }
    });

    test('questions are unique and link to real chapters', () {
      expect(kGuideFaqs.length, 18);
      expect(
        kGuideFaqs.map((faq) => faq.id).toSet().length,
        kGuideFaqs.length,
      );
      for (final faq in kGuideFaqs) {
        expect(faq.question, isNotEmpty);
        expect(faq.answer, isNotEmpty);
        expect(
          guideChapterById(faq.chapterId),
          isNotNull,
          reason: '${faq.id} points at a missing chapter',
        );
      }
    });

    test('search ignores punctuation and requires every word', () {
      expect(
        searchGuideChapters('internet?').map((c) => c.id),
        contains('privacy'),
      );
      expect(searchGuideChapters('daily  allowance').map((c) => c.id),
          contains('daily-allowance'));
      expect(
        searchGuideFaqs('backup encrypted').map((f) => f.id),
        contains('backup-security'),
      );
      expect(searchGuideChapters('').length, kGuideChapters.length);
      expect(searchGuideFaqs('').length, kGuideFaqs.length);
      expect(searchGuideChapters('zzzz-no-match'), isEmpty);
    });
  });

  testWidgets('Help centre lists all chapters and expands an answer',
      (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(
      _simpleApp(settings, const HelpCentreScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse chapters'), findsOneWidget);
    expect(find.text('Replay guided tour'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);

    final firstFaq = find.text('How is my daily allowance calculated?');
    await tester.scrollUntilVisible(
      firstFaq,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(firstFaq);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('With Carry forward (the default)'),
      findsOneWidget,
    );
    expect(find.text('Read chapter 6: Understanding daily allowance'),
        findsOneWidget);
  });

  testWidgets('Search filters chapters and answers, then clears',
      (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(
      _simpleApp(settings, const HelpCentreScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'internet',
    );
    await tester.pumpAndSettle();

    expect(find.text('Guide chapters'), findsOneWidget);
    expect(find.byKey(const Key('help-chapter-privacy')), findsOneWidget);
    expect(find.byKey(const Key('help-chapter-income')), findsNothing);
    expect(find.byKey(const Key('help-faq-internet')), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Browse chapters'), findsOneWidget);
    expect(
        find.byKey(const Key('help-chapter-getting-started')), findsOneWidget);
  });

  testWidgets('Search shows a helpful empty state', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(
      _simpleApp(settings, const HelpCentreScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('help-search-field')),
      'zzzz-no-match',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matches for “zzzz-no-match”'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
    expect(find.text('Ask for help'), findsOneWidget);
  });

  testWidgets('Chapter page shows every required section', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(
      _simpleApp(settings, const HelpCentreScreen()),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('help-chapter-daily-allowance'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Chapter 6 of 12'), findsOneWidget);
    expect(find.text('Understanding daily allowance'), findsWidgets);
    expect(find.text('What it is'), findsOneWidget);

    for (final heading in [
      'Why it matters',
      'Where to find it',
      'Step by step',
      'A real-life example',
      'Common mistakes',
      'Related questions',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(heading), findsOneWidget);
    }
  });

  testWidgets('Replay closes the guide and starts the tutorial',
      (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(_launcher(settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open help'));
    await tester.pumpAndSettle();
    expect(find.text('Browse chapters'), findsOneWidget);

    await tester.tap(find.text('Replay guided tour'));
    await tester.pumpAndSettle();

    expect(find.text('Open help'), findsOneWidget);
    expect(settings.tutorialInProgress, isTrue);
    expect(settings.tutorialStep, 0);
  });

  testWidgets('Settings exposes one Help centre entry', (tester) async {
    final settings = await _settings();
    final storage = StorageService();
    await storage.init();
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

    await tester.pumpWidget(
      MultiProvider(
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('settings-help-centre'));
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Help centre'),
      ),
      findsOneWidget,
    );
    expect(find.text('Browse chapters'), findsOneWidget);
  });

  testWidgets('Help centre survives narrow width and 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await _settings();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HelpCentreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final tile = find.byKey(const Key('help-chapter-getting-started'));
    await tester.scrollUntilVisible(
      tile,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Common mistakes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Common mistakes'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('© 2026 AIX. All rights reserved.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
