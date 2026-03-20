import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/two_way_chat_controller.dart';
import '../models/two_way_message.dart';
import '../theme/app_theme_resolver.dart';

class TwoWayChatView extends StatefulWidget {
  const TwoWayChatView({super.key});

  @override
  State<TwoWayChatView> createState() => _TwoWayChatViewState();
}

class _TwoWayChatViewState extends State<TwoWayChatView> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TwoWayChatController>();
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Transform.rotate(
                angle: math.pi,
                child: _SpeakerPanel(title: 'Guest', role: TwoWaySpeaker.guest),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _SpeakerPanel(
                title: 'Primary',
                role: TwoWaySpeaker.primary,
              ),
            ),
          ],
        ),
        if (controller.messages.isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear chat',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.7,
                ),
              ),
              onPressed: controller.clearMessages,
            ),
          ),
      ],
    );
  }
}

class _SpeakerPanel extends StatefulWidget {
  final String title;
  final TwoWaySpeaker role;

  const _SpeakerPanel({required this.title, required this.role});

  @override
  State<_SpeakerPanel> createState() => _SpeakerPanelState();
}

class _SpeakerPanelState extends State<_SpeakerPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;
  bool _showScrollButton = false;
  int _lastLineCount = 0;

  String _debugScrollStateLabel() {
    if (!_scrollController.hasClients) {
      return '${widget.title}: offset=na max=na latest=na auto=$_shouldAutoScroll';
    }

    final position = _scrollController.position;
    final offset = position.pixels.toStringAsFixed(1);
    final max = position.maxScrollExtent.toStringAsFixed(1);
    final latest = _latestScrollOffset().toStringAsFixed(1);
    return '${widget.title}: offset=$offset max=$max latest=$latest auto=$_shouldAutoScroll';
  }

  double _latestScrollOffset() {
    if (!_scrollController.hasClients) return 0;
    if (widget.role == TwoWaySpeaker.guest) {
      return _scrollController.position.maxScrollExtent;
    }
    return _scrollController.position.maxScrollExtent;
  }

  void _syncScrollState() {
    if (!_scrollController.hasClients) return;
    final latestOffset = _latestScrollOffset();
    final curr = _scrollController.offset;
    final atLatest = (curr - latestOffset).abs() < 50;
    if (atLatest != _shouldAutoScroll || _showScrollButton == atLatest) {
      setState(() {
        _shouldAutoScroll = atLatest;
        _showScrollButton = !atLatest;
      });
    }
  }

  bool get _isPrimary => widget.role == TwoWaySpeaker.primary;

  bool _isCurrentSpeakerMessage(TwoWayMessage message) {
    return message.speaker == widget.role;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncScrollState);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeAutoScrollOnNewMessages(int lineCount) {
    if (lineCount == _lastLineCount) return;
    _lastLineCount = lineCount;
    if (!_shouldAutoScroll) return;

    _scrollToLatestWhenReady();
  }

  void _scrollToLatestWhenReady([int retry = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        if (retry < 4) _scrollToLatestWhenReady(retry + 1);
        return;
      }
      final position = _scrollController.position;
      if (!position.hasContentDimensions) {
        if (retry < 4) _scrollToLatestWhenReady(retry + 1);
        return;
      }
      _scrollController.animateTo(
        _latestScrollOffset(),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TwoWayChatController>();
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    final tokens = resolveAppThemeTokens(theme);

    final activeLanguage = _isPrimary
        ? controller.primaryLanguage
        : controller.guestLanguage;
    final languageLabel = TwoWayChatController.supportedLanguages.entries
        .firstWhere(
          (entry) => entry.value == activeLanguage,
          orElse: () => MapEntry(activeLanguage, activeLanguage),
        )
        .key;
    final isListeningThisPanel =
        controller.isListening && controller.activeSpeaker == widget.role;
    final isListeningOtherPanel =
        controller.isListening && controller.activeSpeaker != widget.role;

    final lines = controller.messages
        .map(
          (m) => (
            text: _isPrimary ? m.primaryText : m.guestText,
            isCurrentSpeaker: _isCurrentSpeakerMessage(m),
          ),
        )
        .where((entry) => entry.text.trim().isNotEmpty)
        .toList(growable: false);

    _maybeAutoScrollOnNewMessages(lines.length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.glassSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${widget.title} Speaker',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(languageLabel, style: textRoles.timestamp),
            ],
          ),
          if (controller.canChangeLanguages) ...[
            const SizedBox(height: 10),
            DropdownMenuFormField<String>(
              initialSelection: activeLanguage,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              requestFocusOnTap: false,
              inputDecorationTheme: InputDecorationThemeData(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownMenuEntries: TwoWayChatController
                  .supportedLanguages
                  .entries
                  .map(
                    (entry) => DropdownMenuEntry<String>(
                      value: entry.value,
                      label: entry.key,
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                if (value == null) return;
                if (_isPrimary) {
                  context.read<TwoWayChatController>().setPrimaryLanguage(
                    value,
                  );
                } else {
                  context.read<TwoWayChatController>().setGuestLanguage(value);
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: lines.isEmpty
                      ? Text(
                          controller.isListening && isListeningThisPanel
                              ? (controller.lastWords.isEmpty
                                    ? 'Listening...'
                                    : controller.lastWords)
                              : 'No messages yet',
                          style: textRoles.helperText,
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            return Text(
                              line.text,
                              style: textRoles.bubbleBody.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              textAlign: line.isCurrentSpeaker
                                  ? TextAlign.right
                                  : TextAlign.left,
                            );
                          },
                        ),
                ),
                if (_showScrollButton)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: const Text('Jump to latest'),
                      onPressed: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _latestScrollOffset(),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                          setState(() {
                            _shouldAutoScroll = true;
                            _showScrollButton = false;
                          });
                        }
                      },
                    ),
                  ),
                if (kDebugMode)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            _debugScrollStateLabel(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              height: 1.0,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (!controller.speechEnabled || isListeningOtherPanel)
                  ? null
                  : () => context.read<TwoWayChatController>().toggleListening(
                      widget.role,
                    ),
              icon: Icon(
                isListeningThisPanel ? Icons.stop_rounded : Icons.mic_rounded,
              ),
              label: Text(isListeningThisPanel ? 'Stop listening' : 'Listen'),
            ),
          ),
          if (controller.speechError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(controller.speechError, style: textRoles.errorText),
          ],
        ],
      ),
    );
  }
}
