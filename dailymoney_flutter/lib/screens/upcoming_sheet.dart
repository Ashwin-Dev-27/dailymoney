import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/tx.dart';
import '../models/upcoming_expense.dart';
import '../providers/settings_provider.dart';
import '../providers/upcoming_provider.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Bottom sheet to add or edit an upcoming bill.
class UpcomingSheet extends StatefulWidget {
  const UpcomingSheet({super.key, this.existing});

  final UpcomingExpense? existing;

  @override
  State<UpcomingSheet> createState() => _UpcomingSheetState();
}

class _UpcomingSheetState extends State<UpcomingSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _dueDate;
  late String _categoryId;
  late bool _repeatMonthly;
  final _formKey = GlobalKey<FormState>();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : _trimZeros(e.amount),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _dueDate = e?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _categoryId = e?.categoryId ?? 'bills';
    _repeatMonthly = e?.repeatMonthly ?? true;
  }

  String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final v = parseAmount(_amount.text);
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final item = UpcomingExpense(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: _parsedAmount!,
      categoryId: _categoryId,
      dueDate: DateTime(_dueDate.year, _dueDate.month, _dueDate.day),
      repeatMonthly: _repeatMonthly,
      note: _note.text.trim(),
    );
    final provider = context.read<UpcomingProvider>();
    final currency = context.read<SettingsProvider>().currencyCode;
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
          _editing
              ? 'Upcoming bill updated'
              : '"${item.title}" tracked · ${fmtMoney(item.amount, currency)}',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final item = widget.existing;
    if (item == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete upcoming bill'),
        content: Text(
          'Remove "${item.title}" from upcoming bills? No transaction will '
          'be recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<UpcomingProvider>().remove(item.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('"${item.title}" removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = context.watch<SettingsProvider>().currencyCode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Edit upcoming bill' : 'New upcoming bill',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reserved from your spendable budget until it is paid.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: scheme.outline),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'Rent, electricity, Netflix…',
                  labelText: 'Bill name',
                  prefixIcon: Icon(LucideIcons.receipt, size: 18),
                  counterText: '',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                autofocus: !_editing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  hintText: '0.00',
                  labelText: 'Amount',
                  prefixText: '${currencyByCode(currency).symbol} ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                validator: (_) =>
                    _parsedAmount == null ? 'Enter an amount above zero' : null,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in categoriesFor(TxType.expense))
                    _categoryChip(context, cat),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    prefixIcon: Icon(LucideIcons.calendarClock, size: 18),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(_dueDate),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _repeatMonthly,
                onChanged: (v) => setState(() => _repeatMonthly = v),
                title: const Text('Repeats every month'),
                subtitle: const Text(
                  'Marking it paid moves it to the same day next month',
                ),
                secondary: const Icon(LucideIcons.repeat, size: 20),
              ),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Optional note',
                  labelText: 'Note',
                  prefixIcon: Icon(LucideIcons.info, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: Icon(_editing ? LucideIcons.check : LucideIcons.plus,
                    size: 18),
                label: Text(_editing ? 'Save changes' : 'Track this bill'),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: AppColors.expense,
                  ),
                  label: const Text(
                    'Delete bill',
                    style: TextStyle(color: AppColors.expense),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context, Category cat) {
    final selected = _categoryId == cat.id;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _categoryId = cat.id),
      avatar: Icon(
        cat.icon,
        size: 15,
        color: selected ? Colors.white : cat.color,
      ),
      label: Text(cat.label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : null,
      ),
      selectedColor: cat.color.withValues(alpha: 0.85),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: selected
            ? cat.color
            : Theme.of(context).dividerTheme.color ?? Colors.grey,
      ),
    );
  }
}
