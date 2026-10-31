import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact DailyMoney developer credit footer.
///
/// Typography mirrors the rest of the application: the brand label uses the
/// same weight/size as list titles, the developer credit uses the same size as
/// normal secondary descriptive text (e.g. empty-state messages), and the
/// version/build/copyright lines use the same size as secondary metadata
/// (list-tile subtitles). No decorative styling or arbitrarily tiny text.
class DailyMoneyFooter extends StatelessWidget {
  const DailyMoneyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final muted = scheme.outline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 12),
          Text(
            'DailyMoney',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: onSurface,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Developed by AIX · Founded by Ashwin Kumar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Version 1.0.0 (Build 1)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: muted.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '© 2026 AIX. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: muted.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
