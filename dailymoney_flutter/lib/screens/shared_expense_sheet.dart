import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/shared_expense.dart';
import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Create or edit a split payment or a debt that is only being tracked.
class SharedExpenseSheet extends StatefulWidget {
  const SharedExpenseSheet({super.key, this.existing});

  final SharedExpense? existing;

  @override
  State<SharedExpenseSheet> createState() => _SharedExpenseSheetState();
}

class _SharedExpenseSheetState extends State<SharedExpenseSheet> {
  late final TextEditingController _title;
  late final TextEditingController _total;
  late final TextEditingController _myShare;
  late final TextEditingController _person;
  late final TextEditingController _note;
  late SharedDirection _direction;
  late DateTime _date;
  late String _categoryId;
  final _formKey = GlobalKey<FormState>();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _total = TextEditingController(
      text: e == null ? '' : fmtAmountInput(e.total),
    );
    _myShare = TextEditingController(
      text: e == null ? '' : fmtAmountInput(e.myShare),
    );
    _person = TextEditingController(text: e?.counterparty ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _direction = e?.direction ?? SharedDirection.owedToMe;
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId ?? 'other';
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _myShare.dispose();
    _person.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final total = parseAmount(_total.text);
    final share = parseAmount(_myShare.text) ?? total;
    if (total == null || total <= 0 || share == null) return;
    final item = SharedExpense(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      total: total,
      myShare: share.clamp(0.0, total).toDouble(),
      direction: _direction,
      date: _date,
      settled: widget.existing?.settled ?? 0,
      categoryId: _categoryId,
      linkedTxId: widget.existing?.linkedTxId,
      counterparty: _person.text.trim(),
      note: _note.text.trim(),
    );
    final provider = context.read<SharedProvider>();
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
          _editing ? 'Shared expense updated' : 'Shared expense tracked',
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
        title: const Text('Remove shared record?'),
        content: Text(
          'Remove "${item.title}"? The linked transaction, if any, stays in '
          'your ledger.',
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
    final provider = context.read<SharedProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.remove(item.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Shared record removed')),
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
                _editing ? 'Edit shared expense' : 'Track money shared',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track the split here. Spending statistics count only your '
                'own share, and money owed is never income.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<SharedDirection>(
                segments: const [
                  ButtonSegment(
                    value: SharedDirection.owedToMe,
                    icon: Icon(LucideIcons.arrowDownLeft, size: 16),
                    label: Text('They owe me'),
                  ),
                  ButtonSegment(
                    value: SharedDirection.iOwe,
                    icon: Icon(LucideIcons.arrowUpRight, size: 16),
                    label: Text('I owe them'),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What was it for?',
                  hintText: 'Dinner, rent, trip…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _person,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Who with? (optional)',
                  hintText: 'A name or nickname',
                  prefixIcon: Icon(LucideIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _total,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Total',
                        prefixText: '$symbol ',
                      ),
                      validator: (v) {
                        final parsed = parseAmount(v ?? '');
                        return (parsed == null || parsed <= 0)
                            ? 'Enter the total'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _myShare,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Your share',
                        prefixText: '$symbol ',
                      ),
                      validator: (v) {
                        final total = parseAmount(_total.text);
                        final share = parseAmount(v ?? '');
                        if (share == null || share < 0) {
                          return 'Enter your share';
                        }
                        if (total != null && share > total) {
                          return 'Not more than total';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _direction == SharedDirection.owedToMe
                    ? 'Your share is what you actually spent. The rest is '
                        'tracked as owed to you.'
                    : 'Your share is what you owe them. It becomes an expense '
                        'only when you record the payment.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
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
              const SizedBox(height: 12),
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
                  for (final cat in categoriesFor(TxType.expense))
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
                      child:
                          Text(_editing ? 'Save changes' : 'Track this split'),
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
