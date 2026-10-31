import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/assistant_service.dart';

class _Message {
  _Message(this.text, {required this.user});

  final String text;
  final bool user;
}

/// Local, rule-based chat about the user's own numbers.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _send(null, '');
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String? text, [String? preset]) {
    final question = (preset ?? text ?? '').trim();
    if (question.isEmpty) {
      // Opening summary.
      if (_messages.isNotEmpty) return;
      final reply = AssistantService.answer(
        '',
        settings: context.read<SettingsProvider>(),
        txs: context.read<TransactionsProvider>(),
        upcoming: context.read<UpcomingProvider>(),
        goals: context.read<GoalsProvider>(),
      );
      setState(() => _messages.add(_Message(reply.text, user: false)));
      return;
    }
    final reply = AssistantService.answer(
      question,
      settings: context.read<SettingsProvider>(),
      txs: context.read<TransactionsProvider>(),
      upcoming: context.read<UpcomingProvider>(),
      goals: context.read<GoalsProvider>(),
    );
    setState(() {
      _messages
        ..add(_Message(question, user: true))
        ..add(_Message(reply.text, user: false));
      _input.clear();
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Money assistant',
              style: TextStyle(color: scheme.onSurface),
            ),
            Text(
              'Answers from data on this phone',
              style: TextStyle(fontSize: 10.5, color: scheme.outline),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                for (final message in _messages) _Bubble(message: message),
                const SizedBox(height: 6),
                _Disclaimer(),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final starter in AssistantService.starters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(
                        starter,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () => _send(starter),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (v) => _send(v),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your money…',
                        isDense: true,
                        prefixIcon: Icon(LucideIcons.messageCircle, size: 17),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: () => _send(_input.text),
                    icon: const Icon(LucideIcons.send, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.user;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: user ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: user ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(LucideIcons.info, size: 12, color: scheme.outline),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Calculated locally from your records. General guidance, not '
            'financial advice.',
            style: TextStyle(fontSize: 10.5, color: scheme.outline),
          ),
        ),
      ],
    );
  }
}
