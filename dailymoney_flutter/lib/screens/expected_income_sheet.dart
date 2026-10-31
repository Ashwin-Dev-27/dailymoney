import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/expected_income.dart';
import '../models/tx.dart';
import '../providers/expected_income_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Create or edit money the user expects to receive.
class ExpectedIncomeSheet extends StatefulWidget {
  const ExpectedIncomeSheet({super.key, this.existing});

  final ExpectedIncome? existing;

  @override
  State<ExpectedIncomeSheet> createState() => _ExpectedIncomeSheetState();
}

class _ExpectedIncomeSheetState extends State<ExpectedIncomeSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late IncomeConfidence _confidence;
  late String _categoryId;
  final _formKey = GlobalKey<FormState>();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : fmtAmountInput(e.amount),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.expectedDate ?? DateTime.now().add(const Duration(days: 7));
    _confidence = e?.confidence ?? IncomeConfidence.medium;
    _categoryId = e?.categoryId ?? 'other-income';
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) return;
    final item = ExpectedIncome(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: amount,
      expectedDate: _date,
      confidence: _confidence,
      received: widget.existing?.received ?? false,
      receivedDate: widget.existing?.receivedDate,
      categoryId: _categoryId,
      note: _note.text.trim(),
    );
    final provider = context.read<ExpectedIncomeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (_editing) {
      await provider.update(item);
    } else {
      await provider.add(item);
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _editing ? 'Expected income updated' : 'Expected income added',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final item = widget.existing;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove expected income?'),
        content: Text(
          'Remove "${item.title}"? If it was already received, the recorded '
          'income transaction is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<ExpectedIncomeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.remove(item.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Expected income removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = context.watch<SettingsProvider>().currencyCode;
    final symbol = currencyByCode(currency).symbol;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editing ? 'Edit expected income' : 'Expected income',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kept outside your balance and allowance until you mark it '
                'received.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What are you expecting?',
                  hintText: 'Salary, freelance payment, scholarship…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$symbol ',
                ),
                validator: (v) {
                  final parsed = parseAmount(v ?? '');
                  return (parsed == null || parsed <= 0)
                      ? 'Enter an amount above zero'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expected date',
                    prefixIcon: Icon(LucideIcons.calendar, size: 18),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(_date),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'How sure are you?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in IncomeConfidence.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _confidence == c,
                      onSelected: (_) => setState(() => _confidence = c),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in categoriesFor(TxType.income))
                    ChoiceChip(
                      selected: _categoryId == cat.id,
                      onSelected: (_) => setState(() => _categoryId = cat.id),
                      avatar: Icon(
                        cat.icon,
                        size: 14,
                        color: _categoryId == cat.id ? Colors.white : cat.color,
                      ),
                      label: Text(cat.label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _categoryId == cat.id ? Colors.white : null,
                      ),
                      selectedColor: cat.color.withValues(alpha: 0.85),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_editing) ...[
                    OutlinedButton.icon(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 17),
                      label: const Text('Remove'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(
                          _editing ? 'Save changes' : 'Add expected income'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
