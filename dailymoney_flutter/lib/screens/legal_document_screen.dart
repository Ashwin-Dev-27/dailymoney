import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/legal_content.dart';
import '../theme.dart';

/// Renders a versioned legal document in a readable, selectable layout.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title, style: TextStyle(color: scheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Copy this document',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: document.plainText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document copied')),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 19),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.fileText,
                  size: 22,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version ${document.version}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Updated ${document.updatedOn}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        document.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warn.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 16, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Private beta: this text describes the current build. It '
                    'has not yet been reviewed by a qualified lawyer and is not '
                    'a claim of regulatory compliance.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: scheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final section in document.sections) ...[
            Text(
              section.title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            for (final paragraph in section.paragraphs) ...[
              Text(
                paragraph,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.62,
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (final bullet in section.bullets) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        bullet,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: scheme.onSurface.withValues(alpha: 0.80),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
