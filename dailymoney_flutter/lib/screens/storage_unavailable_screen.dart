import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/legal_content.dart';
import '../services/secure_store.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Minimal app shown when the encrypted store cannot be opened.
///
/// The normal app is never started in this state, because any write would
/// either fail or (worse) fall back to plaintext. Existing encrypted records
/// are left untouched so a transient Keystore problem can be retried.
class StorageUnavailableApp extends StatelessWidget {
  const StorageUnavailableApp({super.key, required this.storage});

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
        child: const StorageUnavailableScreen(),
      ),
    );
  }
}

class StorageUnavailableScreen extends StatefulWidget {
  const StorageUnavailableScreen({super.key});

  @override
  State<StorageUnavailableScreen> createState() =>
      _StorageUnavailableScreenState();
}

class _StorageUnavailableScreenState extends State<StorageUnavailableScreen> {
  bool _checking = false;
  bool _recovered = false;

  Future<void> _retry() async {
    final storage = context.read<StorageService>();
    setState(() => _checking = true);
    try {
      await SecureStore.retry();
      await storage.init();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _recovered = storage.encryptionEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
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
                          _recovered
                              ? LucideIcons.checkCircle2
                              : LucideIcons.lockKeyhole,
                          size: 30,
                          color: _recovered ? AppColors.income : AppColors.warn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _recovered
                          ? 'Secure storage is available again'
                          : 'Secure storage is unavailable',
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
                      _recovered
                          ? 'Close DailyMoney completely, then reopen it to '
                              'unlock your records.'
                          : 'DailyMoney could not reach the Android Keystore, '
                              'so it cannot encrypt new data. Your existing '
                              'records have not been deleted or rewritten.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: scheme.outline,
                      ),
                    ),
                    if (!_recovered) ...[
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
                                'Do not clear app storage or uninstall: that '
                                    'removes the encrypted records and key.',
                              ),
                              const SizedBox(height: 10),
                              _step(
                                context,
                                '3',
                                'If you restored app data from a backup, the '
                                    'Keystore key does not travel with it. '
                                    'Those records cannot be decrypted here.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No plaintext copy has been created. If the problem '
                        'continues, contact $kSupportEmail.',
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
                      onPressed: _checking || _recovered ? null : _retry,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.refreshCw, size: 17),
                      label: Text(_checking ? 'Checking...' : 'Check again'),
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
