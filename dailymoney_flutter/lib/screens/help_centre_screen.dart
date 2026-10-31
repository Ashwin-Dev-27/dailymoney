import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/user_guide_content.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';
import 'support_screen.dart';

const double _kMaxContentWidth = 760;

/// Searchable user manual, FAQ and guided-tour entry point.
///
/// All wording lives in `services/user_guide_content.dart`; this file only
/// arranges it. That keeps a feature change to one content edit and prevents
/// the guide from drifting away from the app.
class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key});

  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  void _clearSearch() {
    _search.clear();
    _searchFocus.unfocus();
    setState(() => _query = '');
  }

  void _openChapter(GuideChapter chapter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideChapterScreen(chapter: chapter),
      ),
    );
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
    );
  }

  /// Closes this guide (and any chapter page) before starting the tour, so the
  /// overlay lands on the working shell rather than on top of the help pages.
  Future<void> _replayTour() async {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await settings.replayTutorial();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chapters = searchGuideChapters(_query);
    final faqs = searchGuideFaqs(_query);
    final noResults = _searching && chapters.isEmpty && faqs.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Help centre', style: TextStyle(color: scheme.onSurface)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 680 ? 24.0 : 16.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 8),
                children: [
                  if (!_searching) ...[
                    const _HelpHero(),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    key: const Key('help-search-field'),
                    controller: _search,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search allowance, backup, split…',
                      prefixIcon: const Icon(LucideIcons.search, size: 19),
                      suffixIcon: _searching
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(LucideIcons.x, size: 18),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_searching) ...[
                    _TourCard(onTap: _replayTour),
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Browse chapters',
                      subtitle:
                          '${kGuideChapters.length} short chapters, written from '
                          'the way the app actually works.',
                    ),
                    const SizedBox(height: 10),
                    for (final chapter in chapters) ...[
                      _ChapterTile(
                        chapter: chapter,
                        onTap: () => _openChapter(chapter),
                      ),
                      const SizedBox(height: 9),
                    ],
                    const SizedBox(height: 14),
                    _SectionHeading(
                      title: 'Common questions',
                      subtitle: '${kGuideFaqs.length} answers to the things '
                          'people ask most.',
                    ),
                    const SizedBox(height: 10),
                    for (final faq in faqs) ...[
                      _FaqCard(
                        faq: faq,
                        onOpenChapter: _openChapter,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ] else if (noResults)
                    _NoResults(
                      query: _query.trim(),
                      onClear: _clearSearch,
                      onSupport: _openSupport,
                    )
                  else ...[
                    if (chapters.isNotEmpty) ...[
                      _SectionHeading(
                        title: 'Guide chapters',
                        subtitle:
                            '${chapters.length} matching ${chapters.length == 1 ? 'chapter' : 'chapters'}',
                      ),
                      const SizedBox(height: 10),
                      for (final chapter in chapters) ...[
                        _ChapterTile(
                          chapter: chapter,
                          onTap: () => _openChapter(chapter),
                        ),
                        const SizedBox(height: 9),
                      ],
                    ],
                    if (chapters.isNotEmpty && faqs.isNotEmpty)
                      const SizedBox(height: 14),
                    if (faqs.isNotEmpty) ...[
                      _SectionHeading(
                        title: 'Answers',
                        subtitle:
                            '${faqs.length} matching ${faqs.length == 1 ? 'answer' : 'answers'}',
                      ),
                      const SizedBox(height: 10),
                      for (final faq in faqs) ...[
                        _FaqCard(
                          faq: faq,
                          onOpenChapter: _openChapter,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                  const SizedBox(height: 20),
                  _SupportCard(onTap: _openSupport),
                  const DailyMoneyFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HelpHero extends StatelessWidget {
  const _HelpHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              LucideIcons.bookOpenCheck,
              size: 24,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'A practical guide to DailyMoney, written from the app\'s '
                  'real behaviour. Browse a chapter, search a question, or '
                  'replay the guided tour.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.compass,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replay guided tour',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A short walkthrough of the main controls, shown in the '
                      'real app.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.onTap});

  final GuideChapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('help-chapter-${chapter.id}'),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(chapter.icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chapter ${chapter.number}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chapter.summary,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.faq,
    this.onOpenChapter,
    this.showChapterLink = true,
  });

  final GuideFaq faq;
  final ValueChanged<GuideChapter>? onOpenChapter;
  final bool showChapterLink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chapter = guideChapterById(faq.chapterId);
    return Card(
      key: Key('help-faq-${faq.id}'),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(
            LucideIcons.circleHelp,
            size: 19,
            color: scheme.primary,
          ),
          iconColor: scheme.primary,
          collapsedIconColor: scheme.outline,
          title: Text(
            faq.question,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          children: [
            Text(
              faq.answer,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: scheme.onSurface.withValues(alpha: 0.84),
              ),
            ),
            if (showChapterLink &&
                chapter != null &&
                onOpenChapter != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onOpenChapter!(chapter),
                  child: Text(
                    'Read chapter ${chapter.number}: ${chapter.title}',
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.onClear,
    required this.onSupport,
  });

  final String query;
  final VoidCallback onClear;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          children: [
            Icon(LucideIcons.searchX, size: 32, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'No matches for “$query”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Try a simpler word such as allowance, backup, bill, split or '
              'privacy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Clear search'),
                ),
                TextButton(
                  onPressed: onSupport,
                  child: const Text('Ask for help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(LucideIcons.lifeBuoy, size: 21, color: scheme.primary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Still stuck?',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Report a problem, an incorrect calculation, or a privacy '
                      'or security concern.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chapter, with the full what/why/where/steps/example/mistakes layout.
class GuideChapterScreen extends StatelessWidget {
  const GuideChapterScreen({super.key, required this.chapter});

  final GuideChapter chapter;

  Future<void> _replayTour(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await settings.replayTutorial();
  }

  void _openSupport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final related = guideFaqsForChapter(chapter.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${chapter.number}',
            style: TextStyle(color: scheme.onSurface)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 680 ? 24.0 : 16.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 8),
                children: [
                  _ChapterHeader(chapter: chapter),
                  _GuideBlock(
                    icon: LucideIcons.info,
                    title: 'What it is',
                    child: Text(chapter.what, style: _bodyStyle(scheme)),
                  ),
                  _GuideBlock(
                    icon: LucideIcons.sparkles,
                    title: 'Why it matters',
                    child: Text(chapter.why, style: _bodyStyle(scheme)),
                  ),
                  _GuideBlock(
                    icon: LucideIcons.mapPin,
                    title: 'Where to find it',
                    child: Text(chapter.where, style: _bodyStyle(scheme)),
                  ),
                  _GuideBlock(
                    icon: LucideIcons.listChecks,
                    title: 'Step by step',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < chapter.steps.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == chapter.steps.length - 1 ? 0 : 10,
                            ),
                            child: _StepRow(
                              number: i + 1,
                              text: chapter.steps[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _GuideBlock(
                    icon: LucideIcons.lightbulb,
                    title: 'A real-life example',
                    child: _ExampleCard(text: chapter.example),
                  ),
                  _GuideBlock(
                    icon: LucideIcons.alertTriangle,
                    title: 'Common mistakes',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < chapter.mistakes.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == chapter.mistakes.length - 1 ? 0 : 9,
                            ),
                            child: _MistakeCard(mistake: chapter.mistakes[i]),
                          ),
                      ],
                    ),
                  ),
                  if (related.isNotEmpty)
                    _GuideBlock(
                      icon: LucideIcons.circleHelp,
                      title: 'Related questions',
                      child: Column(
                        children: [
                          for (final faq in related) ...[
                            _FaqCard(
                              faq: faq,
                              showChapterLink: false,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  Card(
                    child: InkWell(
                      onTap: () => _replayTour(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Icon(LucideIcons.play,
                                size: 21, color: scheme.primary),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prefer to see it?',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Replay the guided tour, then come back '
                                    'here whenever you need the detail.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: scheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(LucideIcons.chevronRight,
                                size: 18, color: scheme.outline),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SupportCard(onTap: () => _openSupport(context)),
                  const DailyMoneyFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _bodyStyle(ColorScheme scheme) => TextStyle(
        fontSize: 14,
        height: 1.55,
        color: scheme.onSurface.withValues(alpha: 0.88),
      );
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter});

  final GuideChapter chapter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(chapter.icon, size: 24, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chapter ${chapter.number} of ${kGuideChapters.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Semantics(
                  header: true,
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  chapter.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  const _GuideBlock({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.55,
          color: scheme.onSurface.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.mistake});

  final GuideMistake mistake;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              LucideIcons.alertTriangle,
              size: 16,
              color: AppColors.warn,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mistake.problem,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mistake.fix,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
