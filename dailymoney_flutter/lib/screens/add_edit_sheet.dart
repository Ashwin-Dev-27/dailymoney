import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/tx.dart';
import '../models/category.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/budget_alerts.dart';
import '../services/money_plan.dart';
import '../services/sound_service.dart';
import '../utils/format.dart';

/// Bottom sheet to create or edit a transaction.
class AddEditSheet extends StatefulWidget {
  const AddEditSheet({
    super.key,
    this.existing,
    this.prefillTitle,
    this.prefillAmount,
    this.prefillType,
    this.prefillCategoryId,
    this.prefillShared = false,
  });

  final Tx? existing;

  /// Values supplied by another screen, such as the purchase assistant.
  final String? prefillTitle;
  final double? prefillAmount;
  final TxType? prefillType;
  final String? prefillCategoryId;

  /// Opens the split section straight away (expenses only).
  final bool prefillShared;

  @override
  State<AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<AddEditSheet> {
  late TxType _type;
  late String _categoryId;
  late DateTime _date;
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _myShare;
  final TextEditingController _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _shared = false;
  bool _shareTouched = false;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.prefillType ?? TxType.expense;
    _categoryId = existing?.categoryId ??
        widget.prefillCategoryId ??
        (_type.isIncome ? 'salary' : 'groceries');
    _date = existing?.date ?? DateTime.now();
    _title = TextEditingController(
      text: existing?.title ?? widget.prefillTitle ?? '',
    );
    _amount = TextEditingController(
      text: existing == null
          ? (widget.prefillAmount == null
              ? ''
              : _trimZeros(widget.prefillAmount!))
          : _trimZeros(existing.amount),
    );
    final existingShare = existing?.personalShare;
    _shared = existing != null
        ? existingShare != null && existingShare < existing.amount - 0.005
        : widget.prefillShared && _type.isExpense;
    _myShare = TextEditingController(
      text: existingShare != null
          ? _trimZeros(existingShare)
          : (_shared ? _amount.text : ''),
    );
    // Keep an existing split stable when the total is edited; only a brand-new
    // split mirrors the total until the user types their own share.
    _shareTouched = existingShare != null;
    _amount.addListener(_amountChanged);
    _note.text = existing?.note ?? '';
  }

  void _amountChanged() {
    if (_shared && !_shareTouched) {
      _myShare.text = _amount.text;
    }
  }

  void _toggleShared(bool value) {
    setState(() {
      _shared = value;
      _shareTouched = false;
      if (value) _myShare.text = _amount.text;
    });
  }

  String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _myShare.dispose();
    _note.dispose();
    super.dispose();
  }

  void _switchType(TxType t) {
    setState(() {
      _type = t;
      if (t.isIncome) _shared = false;
      // Keep the selection valid: categories are per-type.
      final valid = categoriesFor(t).any((c) => c.id == _categoryId);
      if (!valid) _categoryId = t.isIncome ? 'salary' : 'groceries';
    });
  }

  double? get _parsedAmount {
    final v = parseAmount(_amount.text);
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final lastDate = DateUtils.dateOnly(now);
    final firstDate = DateTime(now.year - 5);
    final initialDate = _date.isBefore(firstDate)
        ? firstDate
        : (_date.isAfter(lastDate) ? lastDate : _date);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      SoundService.instance.error();
      return;
    }
    final amount = _parsedAmount!;
    double? personalShare;
    if (_type.isExpense && _shared) {
      final share = (parseAmount(_myShare.text) ?? amount).clamp(0.0, amount);
      // A full share is not a split; storing null keeps the record identical
      // to an ordinary expense.
      if (share < amount - 0.005) personalShare = share.toDouble();
    }
    final existing = widget.existing;
    final sameType = existing != null && existing.type == _type;
    final tx = Tx(
      id: existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: amount,
      type: _type,
      categoryId: _categoryId,
      date: _date,
      note: _note.text.trim(),
      personalShare: personalShare,
      isSettlement: sameType && _type.isIncome && existing.isSettlement,
      settlementOf: sameType ? existing.settlementOf : null,
    );
    final provider = context.read<TransactionsProvider>();
    final settings = context.read<SettingsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final shared = context.read<SharedProvider>();
    final currency = settings.currencyCode;

    // Capture the allowance before and after saving so an alert only fires on
    // the transaction that actually pushes today over the line.
    final before = MoneyPlan.snapshotFor(
      settings: settings,
      txs: provider,
      upcoming: upcoming,
      goals: goals,
    );

    if (_editing) {
      await provider.update(tx);
    } else {
      await provider.add(tx);
    }
    await shared.syncForTransaction(tx, previous: widget.existing);

    final after = MoneyPlan.snapshotFor(
      settings: settings,
      txs: provider,
      upcoming: upcoming,
      goals: goals,
    );
    BudgetAlerts.maybeNotify(
      settings: settings,
      before: before,
      after: after,
      isExpense: tx.type.isExpense,
      currency: currency,
    );

    if (mounted) {
      SoundService.instance.success();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_editing
              ? 'Transaction updated'
              : '${_type.label} of ${fmtMoney(tx.amount, currency)} added'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = context.watch<SettingsProvider>().currencyCode;

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
                _editing ? 'Edit transaction' : 'New transaction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(
                    value: TxType.expense,
                    icon: Icon(LucideIcons.trendingDown, size: 16),
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: TxType.income,
                    icon: Icon(LucideIcons.trendingUp, size: 16),
                    label: Text('Income'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => _switchType(s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'What was it for?',
                  labelText: 'Title',
                  prefixIcon: Icon(LucideIcons.pencil, size: 18),
                  counterText: '',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give it a title' : null,
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
              if (_type.isExpense) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          Theme.of(context).dividerTheme.color ?? Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _shared,
                        onChanged: _toggleShared,
                        title: const Text(
                          'Split with someone',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Only your share counts as spending',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      if (_shared)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: _myShare,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]'),
                              ),
                            ],
                            onChanged: (_) => _shareTouched = true,
                            decoration: InputDecoration(
                              labelText: 'Your share',
                              prefixText: '${currencyByCode(currency).symbol} ',
                              helperText:
                                  'The rest is tracked as owed to you, not as '
                                  'income.',
                              helperMaxLines: 2,
                            ),
                            validator: (v) {
                              if (!_shared) return null;
                              final total = parseAmount(_amount.text);
                              final share = parseAmount(v ?? '');
                              if (share == null || share <= 0) {
                                return 'Enter your share';
                              }
                              if (total != null && share >= total - 0.005) {
                                return 'Less than the total';
                              }
                              return null;
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
                  for (final cat in categoriesFor(_type))
                    _categoryChip(context, cat),
                ],
              ),
              const SizedBox(height: 14),
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
                label: Text(_editing ? 'Save changes' : 'Add transaction'),
              ),
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
