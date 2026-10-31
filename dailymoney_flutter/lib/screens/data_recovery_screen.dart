import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../services/screen_security.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Minimal app shown when stored data exists but cannot be decrypted.
///
/// It deliberately does not load the normal providers: showing an empty ledger
/// would look like the user's records had disappeared.
class DataRecoveryApp extends StatelessWidget {
  const DataRecoveryApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Provider<StorageService>.value(
        value: storage,
        child: const DataRecoveryScreen(),
      ),
    );
  }
}

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  bool _erasing = false;
  bool _erased = false;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.setBlocked(true);
  }

  Future<void> _erase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var understood = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Erase all data?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This removes every DailyMoney record, preference and the '
                    'app-lock PIN on this phone. The unreadable data cannot be '
                    'exported first.',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This cannot be undone. Only erase if you accept losing '
                    'the records that could not be opened.',
                    style: TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: understood,
                    onChanged: (v) =>
                        setDialogState(() => understood = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I understand this permanently erases the data',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.expense,
                ),
                onPressed: understood ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Erase everything'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _erasing = true);
    try {
      final storage = context.read<StorageService>();
      final security = SecurityProvider(storage);
      await security.resetAll();
      await storage.clearAll();
      await ScreenSecurity.setBlocked(true);
      if (!mounted) return;
      setState(() {
        _erasing = false;
        _erased = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _erasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not erase everything. Close the app and try again, or '
            'uninstall DailyMoney from Android settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
                maxWidth: 560,
              ),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.warn.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          _erased
                              ? LucideIcons.checkCircle2
                              : LucideIcons.lockKeyhole,
                          size: 30,
                          color: _erased ? AppColors.income : AppColors.warn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _erased
                          ? 'Data erased'
                          : 'DailyMoney could not open your data',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _erased
                          ? 'This phone no longer contains DailyMoney records. '
                              'Close and reopen the app to start again.'
                          : 'The records on this phone are still there, but the '
                              'encryption key could not read them. This can '
                              'happen if Android Keystore data was lost, or if '
                              'encrypted app data was copied from another '
                              'device without its key.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: scheme.outline,
                      ),
                    ),
                    if (!_erased) ...[
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _step(
                                context,
                                '1',
                                'Close the app and reopen it once. A temporary '
                                    'Keystore problem may clear on restart.',
                              ),
                              const SizedBox(height: 10),
                              _step(
                                context,
                                '2',
                                'Do not clear app storage or uninstall yet: that '
                                    'would remove the unreadable records too.',
                              ),
                              const SizedBox(height: 10),
                              _step(
                                context,
                                '3',
                                'If you restored app data from a backup, note '
                                    'that the encrypted key cannot travel with '
                                    'it. You will need to start with an empty '
                                    'ledger.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No records have been deleted automatically. Erasing is '
                        'a separate, explicit choice below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _erasing ? null : _erase,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _erased ? AppColors.brand : AppColors.expense,
                      ),
                      icon: _erasing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _erased
                                  ? LucideIcons.trash2
                                  : LucideIcons.alertTriangle,
                              size: 17,
                            ),
                      label: Text(
                        _erasing
                            ? 'Erasing...'
                            : _erased
                                ? 'Erase again'
                                : 'Erase all data and start over',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: const Text('Close DailyMoney'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, String number, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
