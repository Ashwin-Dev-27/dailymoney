import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../providers/expected_income_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/backup_service.dart';
import '../services/data_reset.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// The no-account deletion workflow: scope, backup, confirmation, status.
class DataControlsScreen extends StatefulWidget {
  const DataControlsScreen({super.key});

  @override
  State<DataControlsScreen> createState() => _DataControlsScreenState();
}

class _DataControlsScreenState extends State<DataControlsScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    await copyBackupToClipboard(context);
  }

  Future<void> _restoreFromClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    final ClipboardData? data;
    try {
      data = await Clipboard.getData('text/plain');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the clipboard')),
      );
      return;
    }
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Copy a DailyMoney JSON backup to the clipboard first',
          ),
        ),
      );
      return;
    }

    late final BackupDocument document;
    try {
      document = parseBackup(text);
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup not recognised'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestoreConfirmDialog(document: document),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await restoreBackup(
        storage: context.read<StorageService>(),
        settings: context.read<SettingsProvider>(),
        transactions: context.read<TransactionsProvider>(),
        upcoming: context.read<UpcomingProvider>(),
        goals: context.read<GoalsProvider>(),
        expectedIncome: context.read<ExpectedIncomeProvider>(),
        shared: context.read<SharedProvider>(),
        document: document,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${result.transactions} transactions, '
            '${result.upcoming} bills, ${result.goals} goals, '
            '${result.expectedIncome} expected-income entries and '
            '${result.sharedExpenses} shared records.',
          ),
        ),
      );
    } on BackupRestoreException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The backup could not be restored. Export the records that '
            'are present now and try again.';
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not restore the backup')),
      );
    }
  }

  Future<void> _deleteEverything() async {
    final txs = context.read<TransactionsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final expected = context.read<ExpectedIncomeProvider>();
    final shared = context.read<SharedProvider>();
    final capture = context.read<CaptureProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(
        transactions: txs.count,
        upcoming: upcoming.count,
        goals: goals.count,
        expected: expected.count,
        shared: shared.count,
        detections: capture.count,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await wipeAllData(context);
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All DailyMoney data was erased from this device'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Deletion did not finish. Some records may remain. Close the '
            'app and try again, or uninstall DailyMoney to remove its private '
            'storage.';
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not finish deleting all data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final goals = context.watch<GoalsProvider>();
    final expected = context.watch<ExpectedIncomeProvider>();
    final shared = context.watch<SharedProvider>();
    final capture = context.watch<CaptureProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Data controls', style: TextStyle(color: scheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.smartphone,
                  size: 24,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No account to delete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'DailyMoney stores everything in the app on this '
                        'device. Deleting the data here is the equivalent of '
                        'account deletion. There is no server copy to remove.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    size: 17,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _label(context, 'Before you delete'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.download, size: 20),
                  title: const Text('Export a backup'),
                  subtitle: const Text(
                    'Copies your records as JSON text to the clipboard. Keep '
                    'the copy private and store it somewhere safe.',
                  ),
                  onTap: _busy ? null : _export,
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.upload, size: 20),
                  title: const Text('Restore from clipboard'),
                  subtitle: const Text(
                    'Replaces transactions, bills, goals, expected income and '
                    'shared records from a DailyMoney backup. Security and '
                    'consent settings stay as they are on this device.',
                  ),
                  onTap: _busy ? null : _restoreFromClipboard,
                ),
                _divider(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        size: 15,
                        color: AppColors.warn,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'An exported backup is a separate copy. Deleting app '
                          'data does not erase a file or clipboard copy you '
                          'already made.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'What will be deleted'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _countRow(context, 'Transactions', txs.count),
                  _countRow(context, 'Upcoming bills', upcoming.count),
                  _countRow(context, 'Savings goals', goals.count),
                  _countRow(context, 'Expected income entries', expected.count),
                  _countRow(context, 'Shared expense records', shared.count),
                  _countRow(
                      context, 'Detected payments waiting', capture.count),
                  const SizedBox(height: 6),
                  Text(
                    'Also erased: currency, budget and planning preferences, '
                    'the greeting name, tutorial progress, consent records, '
                    'policy acceptance, theme choice, notification schedules, '
                    'and the app-lock PIN and biometric flag.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'What this does not do'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _notRow(
                    context,
                    'It does not close an account, because DailyMoney has none.',
                  ),
                  _notRow(
                    context,
                    'It does not contact a bank or delete bank records.',
                  ),
                  _notRow(
                    context,
                    'It does not erase Android\'s clipboard or a backup you '
                    'saved elsewhere.',
                  ),
                  _notRow(
                    context,
                    'It does not uninstall the app. Uninstalling removes the '
                    'app itself and its private storage.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: AppColors.expense.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.trash2,
                        size: 20,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Delete all data',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This is immediate and cannot be undone. You will return '
                    'to the welcome screen with an empty app.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.expense,
                      ),
                      onPressed: _busy ? null : _deleteEverything,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.trash2, size: 17),
                      label: Text(
                        _busy
                            ? 'Deleting...'
                            : 'Delete all data on this device',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'If you need a record for a legal, tax or complaint reason, export '
            'or save it before deleting. DailyMoney does not retain a copy on '
            'any server.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: scheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(BuildContext context, String label, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: count == 0 ? scheme.outline : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notRow(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.minus, size: 14, color: AppColors.expense),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: scheme.outline,
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.transactions,
    required this.upcoming,
    required this.goals,
    required this.expected,
    required this.shared,
    required this.detections,
  });

  final int transactions;
  final int upcoming;
  final int goals;
  final int expected;
  final int shared;
  final int detections;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.transactions +
        widget.upcoming +
        widget.goals +
        widget.expected +
        widget.shared +
        widget.detections;
    return AlertDialog(
      title: const Text('Delete all data?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              total == 0
                  ? 'There are no financial records right now. Preferences, '
                      'tutorial progress, consent records and the app-lock PIN '
                      'will still be erased.'
                  : '${widget.transactions} transactions, '
                      '${widget.upcoming} bills, ${widget.goals} goals, '
                      '${widget.expected} expected-income entries, '
                      '${widget.shared} shared records and '
                      '${widget.detections} detections will be erased, along '
                      'with preferences, tutorial progress, consent records '
                      'and the app-lock PIN.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This cannot be undone. Export a backup first if you need a copy.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I understand this cannot be undone',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}

class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog({required this.document});

  final BackupDocument document;

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doc = widget.document;
    final empty = doc.totalRecords == 0;

    return AlertDialog(
      title: const Text('Restore this backup?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The backup contains:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _line(context, 'Transactions', doc.transactions.length),
            _line(context, 'Upcoming bills', doc.upcoming.length),
            _line(context, 'Savings goals', doc.goals.length),
            _line(context, 'Expected income', doc.expectedIncome.length),
            _line(context, 'Shared records', doc.sharedExpenses.length),
            const SizedBox(height: 12),
            Text(
              empty
                  ? 'This backup has no financial records. Restoring it will '
                      'erase the financial records currently on this device.'
                  : 'Restoring replaces the financial records currently on this '
                      'device with the ones above. Budget, currency and display '
                      'preferences from the backup are applied too. The app-lock '
                      'PIN, biometrics, consent choices, notification settings '
                      'and tutorial progress are kept as they are now.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'There is no undo. Export the current records first if you may '
              'need them.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I understand the current financial records will be replaced',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          child: const Text('Restore backup'),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, String label, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: scheme.outline),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
