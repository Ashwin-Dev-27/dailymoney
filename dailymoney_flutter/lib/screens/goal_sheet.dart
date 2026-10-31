import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/savings_goal.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Bottom sheet to create or edit a savings goal.
class GoalSheet extends StatefulWidget {
  const GoalSheet({super.key, this.existing});

  final SavingsGoal? existing;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late final TextEditingController _note;
  late DateTime _targetDate;
  late bool _hasDate;
  final _formKey = GlobalKey<FormState>();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _target = TextEditingController(
      text: e == null ? '' : fmtAmountInput(e.target),
    );
    _saved = TextEditingController(
      text: e == null ? '' : fmtAmountInput(e.saved),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _hasDate = e?.targetDate != null;
    _targetDate =
        e?.targetDate ?? DateTime.now().add(const Duration(days: 180));
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _saved.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(now) ? now : _targetDate,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
        _hasDate = true;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final target = parseAmount(_target.text);
    final saved = parseAmount(_saved.text) ?? 0;
    if (target == null || target <= 0) return;
    final goal = SavingsGoal(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      target: target,
      saved: saved < 0 ? 0 : saved,
      targetDate: _hasDate
          ? DateTime(_targetDate.year, _targetDate.month, _targetDate.day)
          : null,
      note: _note.text.trim(),
    );
    final provider = context.read<GoalsProvider>();
    final currency = context.read<SettingsProvider>().currencyCode;
    final messenger = ScaffoldMessenger.of(context);
    if (_editing) {
      await provider.update(goal);
    } else {
      await provider.add(goal);
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _editing
              ? '"${goal.title}" updated'
              : '"${goal.title}" · target ${fmtMoney(goal.target, currency)}',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final goal = widget.existing;
    if (goal == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete savings goal'),
        content: Text(
          'Remove "${goal.title}"? The money already recorded in your '
          'transactions is not affected.',
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
    await context.read<GoalsProvider>().remove(goal.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('"${goal.title}" removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = context.watch<SettingsProvider>().currencyCode;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.target, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _editing ? 'Edit goal' : 'New savings goal',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What are you saving for?',
                  hintText: 'Emergency fund, laptop, trip…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _target,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Target',
                        prefixText: '${currencyByCode(currency).symbol} ',
                      ),
                      validator: (v) {
                        final amount = parseAmount(v ?? '');
                        return (amount == null || amount <= 0)
                            ? 'Enter a target'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _saved,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Already saved',
                        prefixText: '${currencyByCode(currency).symbol} ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasDate,
                onChanged: (v) => setState(() => _hasDate = v),
                title: const Text('Set a target date'),
                subtitle: const Text(
                  'Used to work out how much to save each month',
                ),
              ),
              if (_hasDate)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.calendar, size: 20),
                  title: const Text('Target date'),
                  trailing: Text(
                    dateLong(_targetDate),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  onTap: _pickDate,
                ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_editing) ...[
                    OutlinedButton.icon(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 17),
                      label: const Text('Delete'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_editing ? 'Save changes' : 'Create goal'),
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

/// Bottom sheet to move money into or out of a goal.
class GoalContributeSheet extends StatefulWidget {
  const GoalContributeSheet({super.key, required this.goal});

  final SavingsGoal goal;

  @override
  State<GoalContributeSheet> createState() => _GoalContributeSheetState();
}

class _GoalContributeSheetState extends State<GoalContributeSheet> {
  final _amount = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _withdraw = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = parseAmount(_amount.text);
    if (value == null || value <= 0) return;
    final delta = _withdraw ? -value : value;
    await context.read<GoalsProvider>().contribute(widget.goal.id, delta);
    if (!mounted) return;
    Navigator.pop(context);
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
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            Text(
              '${fmtMoney(widget.goal.saved, currency)} saved of '
              '${fmtMoney(widget.goal.target, currency)}',
              style: TextStyle(fontSize: 12.5, color: scheme.outline),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(LucideIcons.plus, size: 16),
                  label: Text('Add'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(LucideIcons.minus, size: 16),
                  label: Text('Withdraw'),
                ),
              ],
              selected: {_withdraw},
              onSelectionChanged: (s) => setState(() => _withdraw = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
              ],
              decoration: InputDecoration(
                labelText: _withdraw ? 'Amount to withdraw' : 'Amount to add',
                prefixText: '$symbol ',
              ),
              validator: (v) {
                final amount = parseAmount(v ?? '');
                if (amount == null || amount <= 0) return 'Enter an amount';
                if (_withdraw && amount > widget.goal.saved) {
                  return 'Only ${fmtMoney(widget.goal.saved, currency)} saved';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _apply,
              child: Text(_withdraw ? 'Withdraw' : 'Add to goal'),
            ),
          ],
        ),
      ),
    );
  }
}

String dateLong(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
