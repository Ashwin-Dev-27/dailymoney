import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import '../utils/format.dart';

/// Section title used across the planning screens.
class PlanSectionTitle extends StatelessWidget {
  const PlanSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Rounded callout that explains a rule or a caveat.
class PlanNote extends StatelessWidget {
  const PlanNote({
    super.key,
    required this.text,
    this.icon,
    this.color,
  });

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 15, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled amount in a breakdown.
class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.note,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? note;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: tint.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasized ? 14 : 13,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
                    color: tint,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    note!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 17 : 13.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
              color: color ?? scheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable row for a planning tool.
class PlanToolTile extends StatelessWidget {
  const PlanToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18, color: tint),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ??
          Icon(LucideIcons.chevronRight, size: 17, color: scheme.outline),
    );
  }
}

/// Picks a single amount with the standard currency prefix.
Future<double?> showAmountDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String currencyCode,
  double initial = 0,
  String? helper,
}) {
  final controller = TextEditingController(
    text: initial > 0 ? initial.toStringAsFixed(2) : '',
  );
  final formKey = GlobalKey<FormState>();
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: label,
                  helperText: helper,
                  prefixText: '${currencyByCode(currencyCode).symbol} ',
                ),
                validator: (value) {
                  final parsed = parseAmount(value ?? '');
                  return (parsed == null || parsed <= 0)
                      ? 'Enter an amount above zero'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'This changes your plan only. It never moves money in your '
                'bank account.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, parseAmount(controller.text));
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// Color for a safe / tight / over state.
Color planToneColor(BuildContext context,
    {required bool warn, required bool bad}) {
  if (bad) return AppColors.expense;
  if (warn) return AppColors.warn;
  return Theme.of(context).colorScheme.primary;
}
