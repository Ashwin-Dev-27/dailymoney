import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
import 'package:flutter/material.dart' show MaterialApp, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/screens/reports_screen.dart';
import 'package:dailymoney/services/demo_seed.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/theme.dart';
import 'package:dailymoney/utils/format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports fit a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.setMonthlyBudget(5000);
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    await transactions.addAll(DemoSeed().generate());
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    await upcoming.addAll(DemoSeed().generateUpcoming());

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: transactions),
            ChangeNotifierProvider.value(value: upcoming),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: ReportsScreen(initialMonth: monthOf(DateTime.now())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }

    expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
  });
}
