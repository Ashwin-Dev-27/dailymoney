import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/capture_provider.dart';
import 'providers/expected_income_provider.dart';
import 'providers/goals_provider.dart';
import 'providers/security_provider.dart';
import 'providers/shared_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/upcoming_provider.dart';
import 'screens/data_recovery_screen.dart';
import 'services/notification_service.dart';
import 'services/screen_security.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final settings = SettingsProvider(storage);
  await settings.load();
  await ScreenSecurity.setBlocked(settings.blockScreenshots);

  final transactions = TransactionsProvider(storage);
  await transactions.load();

  final upcoming = UpcomingProvider(storage);
  await upcoming.load();

  final goals = GoalsProvider(storage);
  await goals.load();

  final capture = CaptureProvider(storage);
  await capture.load(acceptNative: settings.autoCapture);

  final expectedIncome = ExpectedIncomeProvider(storage);
  await expectedIncome.load();

  final shared = SharedProvider(storage);
  await shared.load();

  final security = SecurityProvider(storage);
  await security.load();

  // A corrupt payload or a missing Keystore key must not look like an empty
  // ledger. Stop before the welcome/shell and offer an explicit recovery path.
  if (storage.hasReadFailure) {
    runApp(DataRecoveryApp(storage: storage));
    return;
  }

  // First launch no longer injects financial records automatically. The
  // welcome screen offers sample data as an explicit, reversible choice, and
  // Settings > Data management can add or delete it later.

  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: transactions),
        ChangeNotifierProvider.value(value: upcoming),
        ChangeNotifierProvider.value(value: goals),
        ChangeNotifierProvider.value(value: capture),
        ChangeNotifierProvider.value(value: expectedIncome),
        ChangeNotifierProvider.value(value: shared),
        ChangeNotifierProvider.value(value: security),
      ],
      child: const DailyMoneyApp(),
    ),
  );
}
