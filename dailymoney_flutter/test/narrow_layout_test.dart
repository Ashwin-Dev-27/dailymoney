import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
import 'package:flutter/material.dart' show Size;
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
import 'package:dailymoney/services/demo_seed.dart';
import 'package:dailymoney/services/storage_service.dart';

/// The app must lay out cleanly on a 393 dp-wide phone (1080 px @ 2.75x).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all tabs fit a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<List<FlutterErrorDetails>> captureErrors(
        Future<void> Function() action) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await action();
      } finally {
        FlutterError.onError = previous;
      }
      return errors;
    }

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.dismissWelcome();
    // Exercise the full Home budget card and monthly bar, not just the
    // first-run "set a budget" state.
    await settings.setMonthlyBudget(5000);
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    await transactions.addAll(DemoSeed().generate());
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    await upcoming.addAll(DemoSeed().generateUpcoming());
    final goals = GoalsProvider(storage);
    await goals.load();
    await goals.addAll(DemoSeed().generateGoals());
    final capture = CaptureProvider(storage);
    await capture.load();
    final security = SecurityProvider(storage);
    await security.load();
    final expected = ExpectedIncomeProvider(storage);
    await expected.load();
    final shared = SharedProvider(storage);
    await shared.load();

    final failures = <String, List<FlutterErrorDetails>>{};

    final homeErrors = await captureErrors(() async {
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
    });
    if (homeErrors.isNotEmpty) failures['Home'] = homeErrors;

    // The reports screen has the densest rows; check it at phone width too.
    final reportErrors = await captureErrors(() async {
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
    });
    if (reportErrors.isNotEmpty) failures['Reports'] = reportErrors;
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Scroll Home so the populated upcoming section is laid out.
    final upcomingErrors = await captureErrors(() async {
      await tester.scrollUntilVisible(find.text('Upcoming bills'), 300);
      await tester.pumpAndSettle();
    });
    if (upcomingErrors.isNotEmpty) failures['Upcoming'] = upcomingErrors;

    for (final tab in ['Insights', 'Activity', 'Settings', 'Home']) {
      final errors = await captureErrors(() async {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      });
      if (errors.isNotEmpty) failures[tab] = errors;
    }

    final details = failures.entries
        .map((e) => '── ${e.key} ──\n${e.value.join('\n')}')
        .join('\n');
    expect(failures, isEmpty, reason: details);
  });
}
