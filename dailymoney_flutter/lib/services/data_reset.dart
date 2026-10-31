import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../providers/expected_income_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import 'storage_service.dart';

/// Erases every record and preference, then reloads the providers in place.
///
/// Used by "forgot PIN" and "delete all data". Kept in one place so both paths
/// cannot drift apart.
Future<void> wipeAllData(BuildContext context) async {
  final storage = context.read<StorageService>();
  final security = context.read<SecurityProvider>();
  final settings = context.read<SettingsProvider>();
  final txs = context.read<TransactionsProvider>();
  final upcoming = context.read<UpcomingProvider>();
  final goals = context.read<GoalsProvider>();
  final capture = context.read<CaptureProvider>();
  final expected = context.read<ExpectedIncomeProvider>();
  final shared = context.read<SharedProvider>();

  await storage.clearAll();
  await security.resetAll();
  await settings.resetToDefaults();
  await txs.load();
  await upcoming.load();
  await goals.load();
  await capture.load();
  await expected.load();
  await shared.load();
}
