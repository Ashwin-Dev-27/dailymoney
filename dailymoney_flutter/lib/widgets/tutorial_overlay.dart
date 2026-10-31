import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme.dart';

/// Global targets owned by the shell and attached to real controls.
class TutorialAnchors {
  final GlobalKey overview = GlobalKey(debugLabel: 'tour-overview');
  final GlobalKey allowance = GlobalKey(debugLabel: 'tour-allowance');
  final GlobalKey addButton = GlobalKey(debugLabel: 'tour-add');
  final GlobalKey categories = GlobalKey(debugLabel: 'tour-categories');
  final GlobalKey budget = GlobalKey(debugLabel: 'tour-budget');
  final GlobalKey whatIf = GlobalKey(debugLabel: 'tour-what-if');
  final GlobalKey insights = GlobalKey(debugLabel: 'tour-insights');
  final GlobalKey nightSummary = GlobalKey(debugLabel: 'tour-night');
  final GlobalKey privacy = GlobalKey(debugLabel: 'tour-privacy');
  final GlobalKey data = GlobalKey(debugLabel: 'tour-data');
}

class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    required this.anchor,
    required this.tab,
    required this.icon,
    this.scrollAlignment = 0.3,
    this.fallback,
    this.actionLabel,
    this.openAddSheet = false,
  });

  final String title;
  final String body;
  final GlobalKey anchor;
  final int tab;
  final IconData icon;
  final double scrollAlignment;
  final String? fallback;
  final String? actionLabel;
  final bool openAddSheet;
}

List<TutorialStep> tutorialStepsFor(TutorialAnchors anchors) => [
      TutorialStep(
        title: 'Your money at a glance',
        body: 'This is your confirmed balance and this month\'s income and '
            'spending. It changes only when you record a transaction.',
        anchor: anchors.overview,
        tab: 0,
        icon: LucideIcons.wallet,
        scrollAlignment: 0.05,
      ),
      TutorialStep(
        title: 'Today\'s spending money',
        body: 'Your monthly budget is spread across the days left. Bills and '
            'protected money are set aside first, so this is what is safe to '
            'spend today.',
        anchor: anchors.allowance,
        tab: 0,
        icon: LucideIcons.calendarDays,
        scrollAlignment: 0.1,
      ),
      TutorialStep(
        title: 'Record an expense',
        body:
            'Tap + to open the entry sheet. Nothing is saved until you review '
            'it and tap Add, so you can look around safely.',
        anchor: anchors.addButton,
        tab: 0,
        icon: LucideIcons.plus,
        actionLabel: 'Open the entry sheet',
        openAddSheet: true,
      ),
      TutorialStep(
        title: 'See where money goes',
        body:
            'Insights groups your spending by category and shows the last six '
            'months. The breakdown fills in as you record expenses.',
        anchor: anchors.categories,
        tab: 1,
        icon: LucideIcons.pieChart,
        scrollAlignment: 0.9,
        fallback:
            'There are no expenses to chart yet. Add a transaction and the '
            'category breakdown will appear here.',
      ),
      TutorialStep(
        title: 'Set the monthly budget',
        body: 'DailyMoney uses this amount to calculate the daily allowance. '
            'You can change it at any time without losing your records.',
        anchor: anchors.budget,
        tab: 3,
        icon: LucideIcons.wallet,
        scrollAlignment: 0.15,
      ),
      TutorialStep(
        title: 'Try a future scenario',
        body: 'What if & purchase check estimates a purchase, a delayed income '
            'or a bill increase before you spend. Results are estimates, not '
            'promises.',
        anchor: anchors.whatIf,
        tab: 3,
        icon: LucideIcons.gitBranch,
        scrollAlignment: 0.7,
      ),
      TutorialStep(
        title: 'Insights and alerts',
        body:
            'Insights highlights patterns and category changes. Budget alerts '
            'can warn you when the daily allowance is nearly used; they are '
            'optional and live under Notifications.',
        anchor: anchors.insights,
        tab: 1,
        icon: LucideIcons.trendingUp,
        scrollAlignment: 0.05,
        fallback:
            'Insights will fill in after you record some transactions. You can '
            'continue the tour anyway.',
      ),
      TutorialStep(
        title: 'Nightly summary',
        body:
            'Turn this on for a short end-of-day summary. Android notification '
            'permission is requested only when you enable a notification '
            'feature.',
        anchor: anchors.nightSummary,
        tab: 3,
        icon: LucideIcons.moon,
        scrollAlignment: 0.72,
      ),
      TutorialStep(
        title: 'Privacy and permissions',
        body: 'Permissions & data explains what the app can access, whether '
            'storage is encrypted, and how to export your records.',
        anchor: anchors.privacy,
        tab: 3,
        icon: LucideIcons.shieldCheck,
        scrollAlignment: 0.55,
      ),
      TutorialStep(
        title: 'Your data controls',
        body: 'Delete all transactions here, or open Data controls under '
            'Help & support > Legal & privacy for a full reset of every record, '
            'preference and the app-lock PIN.',
        anchor: anchors.data,
        tab: 3,
        icon: LucideIcons.database,
        scrollAlignment: 0.9,
      ),
    ];

/// A real overlay over the working shell: dimmed background, spotlight,
/// pointer, tooltip and completion card.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.anchors,
    required this.stepIndex,
    required this.onNavigateTab,
    required this.onOpenAddSheet,
  });

  final TutorialAnchors anchors;
  final int stepIndex;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onOpenAddSheet;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  Rect? _target;
  int _lastStep = -1;
  int _measureRetries = 0;
  bool _reducedMotion = false;

  List<TutorialStep> get _steps => tutorialStepsFor(widget.anchors);

  SettingsProvider get _settings => context.read<SettingsProvider>();

  int get _stepIndex => widget.stepIndex.clamp(0, _steps.length + 1);

  bool get _complete => _stepIndex >= _steps.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncPulse();
    _prepareStep();
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex) {
      _lastStep = -1;
      _syncPulse();
      _prepareStep();
    }
  }

  void _syncPulse() {
    if (_reducedMotion || _complete) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didChangeMetrics() {
    _measureLater();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  void _prepareStep() {
    final index = _stepIndex;
    if (_complete || index == _lastStep) return;
    _lastStep = index;
    _measureRetries = 0;
    final step = _steps[index];
    widget.onNavigateTab(step.tab);
    _measureLater(ensureVisible: true);
  }

  void _measureLater({bool ensureVisible = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final step = _complete ? null : _steps[_stepIndex];
      if (step == null) {
        if (_target != null) setState(() => _target = null);
        return;
      }
      final targetContext = step.anchor.currentContext;
      if (targetContext == null) {
        if (_measureRetries < 6) {
          _measureRetries++;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _measureLater(ensureVisible: ensureVisible);
          });
        }
        if (_target != null) setState(() => _target = null);
        return;
      }
      if (ensureVisible) {
        try {
          final duration = _reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 320);
          await Scrollable.ensureVisible(
            targetContext,
            alignment: step.scrollAlignment,
            duration: duration,
            curve: Curves.easeOutCubic,
          );
          if (duration > Duration.zero) {
            await Future.delayed(duration);
          }
        } catch (_) {
          // The target may not be inside a scrollable. Measuring still works.
        }
      }
      // Re-measure after layout settles (covers nested scrollables).
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted || !targetContext.mounted) return;
      final box = targetContext.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        if (_measureRetries < 6) {
          _measureRetries++;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _measureLater(ensureVisible: ensureVisible);
          });
        }
        if (_target != null) setState(() => _target = null);
        return;
      }
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      _measureRetries = 0;
      if (_target != rect) setState(() => _target = rect);
    });
  }

  Future<void> _next() async {
    final settings = _settings;
    if (_stepIndex >= _steps.length - 1) {
      await settings.markTutorialCompleted();
      return;
    }
    await settings.setTutorialStep(_stepIndex + 1);
    _lastStep = -1;
    _prepareStep();
  }

  Future<void> _back() async {
    if (_stepIndex == 0) return;
    await _settings.setTutorialStep(_stepIndex - 1);
    _lastStep = -1;
    _prepareStep();
  }

  @override
  Widget build(BuildContext context) {
    final step = _complete ? null : _steps[_stepIndex];
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _next();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _back();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _settings.skipTutorial();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        liveRegion: true,
        label: step == null
            ? 'Tutorial complete. You are ready to use DailyMoney.'
            : 'Tutorial step ${_stepIndex + 1} of ${_steps.length}. '
                '${step.title}. ${step.body}',
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _SpotlightPainter(
                      target: _target,
                      scheme: Theme.of(context).colorScheme,
                      brand: AppColors.brand,
                      pulse: _reducedMotion ? 0.5 : _pulse.value,
                    ),
                  ),
                ),
              ),
            ),
            if (!_complete && _target != null)
              Positioned(
                left: _target!.right + 6 <= size.width
                    ? math.min(size.width - 40, _target!.right + 6)
                    : math.max(0, _target!.left - 40),
                top: math.max(0, _target!.top - 6),
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final bob = _reducedMotion
                          ? 0.0
                          : math.sin(_pulse.value * math.pi) * 8;
                      return Transform.translate(
                        offset: Offset(0, bob),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.touch_app_rounded,
                      size: 34,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_complete)
              _CompletionCard(
                onClose: () => _settings.finishTutorial(),
              )
            else
              _tooltip(context, step!, size, bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _tooltip(
    BuildContext context,
    TutorialStep step,
    Size size,
    double bottomInset,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final rawTarget = _target;
    final targetVisible = rawTarget != null &&
        rawTarget.bottom > 0 &&
        rawTarget.top < size.height - bottomInset;
    final target = targetVisible ? rawTarget : null;
    const gap = 14.0;
    const margin = 16.0;
    final availableWidth = math.max(220.0, size.width - margin * 2);
    final cardWidth = math.min(360.0, availableWidth);

    double? top;
    double? bottom;
    double maxHeight = size.height - bottomInset - margin * 2;

    if (target == null) {
      bottom = math.max(margin + bottomInset, 24);
      maxHeight = math.min(maxHeight, 300);
    } else {
      final above = target.top - gap - margin;
      final below = size.height - bottomInset - target.bottom - gap - margin;
      final useAbove = above >= below;
      if (useAbove) {
        bottom = size.height - target.top + gap;
        maxHeight = math.max(80, above);
      } else {
        top = target.bottom + gap;
        maxHeight = math.max(80, below);
      }
    }

    final alignment =
        (top != null) ? Alignment.topCenter : Alignment.bottomCenter;
    return Positioned(
      left: margin,
      right: margin,
      top: top,
      bottom: bottom,
      child: Align(
        alignment: alignment,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            maxHeight: math.min(maxHeight, size.height * 0.62),
          ),
          child: Material(
            color: scheme.surface,
            elevation: 18,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          step.icon,
                          size: 18,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Text(
                        '${_stepIndex + 1} / ${_steps.length}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_stepIndex + 1) / _steps.length,
                      minHeight: 5,
                      backgroundColor:
                          scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    target == null && step.fallback != null
                        ? step.fallback!
                        : step.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: scheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                  if (step.actionLabel != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          step.openAddSheet ? widget.onOpenAddSheet : null,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(step.actionLabel!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _settings.skipTutorial(),
                        child: const Text('Skip tour'),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _stepIndex == 0 ? null : _back,
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _next,
                        child: Text(
                          _stepIndex == _steps.length - 1 ? 'Finish' : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: scheme.surface,
            elevation: 20,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      size: 34,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You\'re ready!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DailyMoney will help you understand where your money '
                    'goes. You can replay this tour any time from Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onClose,
                      child: const Text('Start using DailyMoney'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.scheme,
    required this.brand,
    required this.pulse,
  });

  final Rect? target;
  final ColorScheme scheme;
  final Color brand;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = const Color(0xC2000000);
    if (target == null) {
      canvas.drawRect(full, dim);
      return;
    }

    final hole = RRect.fromRectAndRadius(
      target!.inflate(8),
      Radius.circular(math.min(28, target!.shortestSide / 2)),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(hole),
    );
    canvas.drawPath(path, dim);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = brand.withValues(alpha: 0.55 + pulse * 0.35);
    canvas.drawRRect(hole, ring);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = brand.withValues(alpha: 0.10 + pulse * 0.10);
    canvas.drawRRect(hole.inflate(3), glow);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.pulse != pulse ||
      oldDelegate.scheme != scheme;
}
