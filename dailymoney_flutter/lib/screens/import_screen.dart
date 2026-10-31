import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/statement_parser.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Paste a bank/UPI CSV export, preview it, then commit the selected rows.
///
/// This is the offline stepping stone for bank connections: the user stays in
/// control of exactly which rows enter the ledger.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _csv = TextEditingController();
  List<StatementRow> _rows = const [];
  final Set<int> _selected = {};
  bool _importing = false;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  void _parse() {
    final rows = StatementParser.parse(_csv.text);
    setState(() {
      _rows = rows;
      _selected
        ..clear()
        ..addAll(List.generate(rows.length, (i) => i));
    });
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No rows found. Include date, description and amount (or '
            'debit/credit) columns.',
          ),
        ),
      );
    }
  }

  Future<void> _import() async {
    if (_selected.isEmpty || _importing) return;
    setState(() => _importing = true);
    final txs = context.read<TransactionsProvider>();
    final currency = context.read<SettingsProvider>().currencyCode;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final existing = txs.all.map(_fingerprintOf).toSet();
    final fresh = <Tx>[];
    var duplicates = 0;
    for (final index in _selected) {
      final row = _rows[index];
      if (!existing.add(row.fingerprint)) {
        duplicates++;
        continue;
      }
      fresh.add(Tx(
        id: const Uuid().v4(),
        title: row.title,
        amount: row.amount,
        type: row.type,
        categoryId: categoryIdForText(row.title, income: row.type.isIncome),
        date: row.date,
        note: 'Imported statement',
      ));
    }

    if (fresh.isNotEmpty) await txs.addAll(fresh);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fresh.isEmpty
              ? 'All selected rows were already recorded'
              : 'Imported ${fresh.length} transactions'
                  '${duplicates > 0 ? ' · $duplicates duplicates skipped' : ''} '
                  '· ${fmtMoney(fresh.fold(0.0, (s, t) => s + t.amount), currency)}',
        ),
      ),
    );
  }

  String _fingerprintOf(Tx t) =>
      '${t.date.year}-${twoDigits(t.date.month)}-${twoDigits(t.date.day)}|'
      '${t.amount.toStringAsFixed(2)}|${t.title.toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = context.watch<SettingsProvider>().currencyCode;

    final selectedRows = _selected.map((i) => _rows[i]).toList(growable: false);
    final expenses = selectedRows
        .where((r) => r.type.isExpense)
        .fold(0.0, (sum, r) => sum + r.amount);
    final income = selectedRows
        .where((r) => r.type.isIncome)
        .fold(0.0, (sum, r) => sum + r.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Import statement',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.fileSpreadsheet,
                    size: 22, color: scheme.primary),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paste a CSV from your bank or UPI app',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nothing is uploaded. Columns can be date, description, '
                        'amount — or separate debit/credit columns.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.outline,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _csv,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'date,description,amount\n'
                  '01/10/2026,Blinkit order,450.50\n'
                  '02/10/2026,Salary credit,45000',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _csv.clear();
                    _rows = const [];
                    _selected.clear();
                  }),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _parse,
                  icon: const Icon(LucideIcons.search, size: 16),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_rows.length} rows found',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == _rows.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(List.generate(_rows.length, (i) => i));
                    }
                  }),
                  child: Text(
                    _selected.length == _rows.length
                        ? 'Deselect all'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_selected.length} selected · '
              '${fmtMoney(expenses, currency)} out · '
              '${fmtMoney(income, currency)} in',
              style: TextStyle(fontSize: 11.5, color: scheme.outline),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    CheckboxListTile(
                      value: _selected.contains(i),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      }),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        _rows[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${dayLabel(_rows[i].date)} · '
                        '${categoryById(categoryIdForText(_rows[i].title, income: _rows[i].type.isIncome)).label}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      secondary: Text(
                        '${_rows[i].type.isExpense ? '-' : '+'}'
                        '${fmtMoney(_rows[i].amount, currency)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _rows[i].type.isExpense
                              ? AppColors.expense
                              : AppColors.income,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _selected.isEmpty || _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.download, size: 18),
              label: Text(
                _importing
                    ? 'Importing…'
                    : 'Import ${_selected.length} transactions',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
