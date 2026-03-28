import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/l10n/app_localizations_ext.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/theme/app_theme_resolver.dart';

/// A scrollable list of chat messages (speech results).  Only rebuilds when the
/// underlying message list changes.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatMessageListState createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  int _lastMessageSnapshotHash = 0;
  final Set<String> _expandedOriginalMessageIds = <String>{};
  String? _hoverHintMessageId;

  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;
  bool _showScrollButton = false;

  Color _speakerChipBackground(
    int? speaker,
    bool isPreferred,
    AppThemeTokens tokens,
    ThemeData theme,
  ) {
    if (speaker == null || tokens.speakerColors.isEmpty) {
      return isPreferred
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface.withValues(alpha: 0.6);
    }

    final base = tokens.speakerColors[speaker % tokens.speakerColors.length];
    return base.withValues(alpha: isPreferred ? 0.62 : 0.5);
  }

  Color _speakerChipTextColor(Color background, ThemeData theme) {
    final contrastWithWhite =
        (Colors.white.computeLuminance() + 0.05) /
        (background.computeLuminance() + 0.05);
    final contrastWithBlack =
        (background.computeLuminance() + 0.05) /
        (Colors.black.computeLuminance() + 0.05);

    if (contrastWithWhite >= contrastWithBlack) {
      return Colors.white;
    }
    return Colors.black;
  }

  String _formatTime(BuildContext context, DateTime ts) {
    final time = TimeOfDay.fromDateTime(ts);
    return time.format(context);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // if user scrolls away from bottom, don't auto-scroll on new messages
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final curr = _scrollController.offset;
      final atBottom = (maxScroll - curr) < 50;
      if (atBottom != _shouldAutoScroll) {
        setState(() {
          _shouldAutoScroll = atBottom;
          _showScrollButton = !atBottom;
        });
      }
    });
  }

  int _computeMessageSnapshotHash(List<ChatMessage> messages) {
    return Object.hashAll(
      messages.map(
        (msg) => Object.hash(
          msg.original,
          msg.translation,
          msg.speaker,
          msg.timestamp.microsecondsSinceEpoch,
        ),
      ),
    );
  }

  void _maybeAutoScrollOnMessageChanges(List<ChatMessage> messages) {
    final snapshotHash = _computeMessageSnapshotHash(messages);
    if (snapshotHash == _lastMessageSnapshotHash) return;
    _lastMessageSnapshotHash = snapshotHash;
    if (!_shouldAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpeechController>();
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    final tokens = resolveAppThemeTokens(theme);
    final hideTranslatedOriginalText = controller.hideTranslatedOriginalText;
    final l10n = context.l10n;

    var messages = controller.chatMessages;
    final optimisticMessages = controller.getOptimisticMessages();
    if (optimisticMessages.isNotEmpty) {
      messages = [...messages, ...optimisticMessages];
    }
    _maybeAutoScrollOnMessageChanges(messages);

    if (messages.isEmpty) {
      final isListening = controller.isListening;
      final speechEnabled = controller.speechEnabled;
      final msgText = isListening
          ? l10n.listeningStatus
          : (speechEnabled
                ? l10n.tapMicToStartListening
                : l10n.speechNotAvailable);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.glassSurface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        isListening
                            ? Icons.hearing_rounded
                            : Icons.mic_none_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(msgText, style: textRoles.statusMessage),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          itemCount: messages.length,
          separatorBuilder: (context, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isPreferred =
                msg.speaker != null &&
                msg.speaker == controller.preferredSpeaker;
            final isPrimaryStyled =
                controller.preferredSpeaker != null && isPreferred;
            final hasTranslation =
                msg.translation != null ||
                msg.groups.any((group) => group.translation != null);
            final canToggleOriginal =
                hideTranslatedOriginalText && msg.isFinal && hasTranslation;
            final showOriginal =
                !hideTranslatedOriginalText ||
                !msg.isFinal ||
                _expandedOriginalMessageIds.contains(msg.id);
            final textColor = theme.colorScheme.onSurface;
            final speakerChipColor = _speakerChipBackground(
              msg.speaker,
              isPreferred,
              tokens,
              theme,
            );

            return Align(
              key: ValueKey<String>('chat_row_${msg.id}'),
              alignment: isPreferred
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isPreferred ? 56 : 0,
                  right: isPreferred ? 0 : 56,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.88,
                  ),
                  child: Column(
                    crossAxisAlignment: isPrimaryStyled
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment:
                            controller.preferredSpeaker != null && isPreferred
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg.speaker != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: speakerChipColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n.speakerLabel(msg.speaker! + 1),
                                  style: textRoles.speakerChip.copyWith(
                                    color: _speakerChipTextColor(
                                      speakerChipColor,
                                      theme,
                                    ),
                                  ),
                                ),
                              ),
                            if (msg.speaker != null) const SizedBox(width: 8),
                            Text(
                              _formatTime(context, msg.timestamp),
                              style: textRoles.timestamp.copyWith(
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      MouseRegion(
                        cursor: canToggleOriginal
                            ? SystemMouseCursors.click
                            : MouseCursor.defer,
                        onEnter: canToggleOriginal
                            ? (_) {
                                setState(() {
                                  _hoverHintMessageId = msg.id;
                                });
                              }
                            : null,
                        onExit: (_) {
                          if (_hoverHintMessageId != msg.id) return;
                          setState(() {
                            _hoverHintMessageId = null;
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              key: ValueKey<String>('chat_bubble_${msg.id}'),
                              behavior: HitTestBehavior.translucent,
                              onTap: canToggleOriginal
                                  ? () {
                                      setState(() {
                                        if (_expandedOriginalMessageIds
                                            .contains(msg.id)) {
                                          _expandedOriginalMessageIds.remove(
                                            msg.id,
                                          );
                                        } else {
                                          _expandedOriginalMessageIds.add(
                                            msg.id,
                                          );
                                        }
                                      });
                                    }
                                  : null,
                              child: _ChatMessageContent(
                                message: msg,
                                isPrimaryStyled: isPrimaryStyled,
                                textColor: textColor,
                                textRoles: textRoles,
                                showOriginal: showOriginal,
                              ),
                            ),
                            if (canToggleOriginal &&
                                _hoverHintMessageId == msg.id)
                              Positioned(
                                top: -34,
                                left: isPrimaryStyled ? null : 0,
                                right: isPrimaryStyled ? 0 : null,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.inverseSurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        showOriginal
                                            ? l10n.hideOriginal
                                            : l10n.showOriginal,
                                        style: textRoles.helperText.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onInverseSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_showScrollButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.arrow_downward_rounded),
                label: Text(l10n.jumpToLatest),
                onPressed: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
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
          ),
      ],
    );
  }
}

class _ChatMessageContent extends StatelessWidget {
  static const Duration _originalToggleDuration = Duration(milliseconds: 220);

  final ChatMessage message;
  final bool isPrimaryStyled;
  final Color textColor;
  final AppThemeTextRoles textRoles;
  final bool showOriginal;

  const _ChatMessageContent({
    required this.message,
    required this.isPrimaryStyled,
    required this.textColor,
    required this.textRoles,
    required this.showOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final bodyStyle = textRoles.bubbleBody.copyWith(color: textColor);
    final translationStyle = textRoles.bubbleTranslation.copyWith(
      color: textColor.withValues(alpha: 0.9),
    );
    final controller = context.read<SpeechController>();
    final l10n = context.l10n;
    final contentAlignment = isPrimaryStyled
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final translationText = _resolvedTranslationText(message);
    final hasTranslation = translationText != null;
    final shouldCollapseOriginal = message.isFinal && hasTranslation;
    Widget expandToBubbleWidth(Widget child) {
      return SizedBox(width: double.infinity, child: child);
    }

    final originalContent = expandToBubbleWidth(
      message.groups.isEmpty
          ? _AnimatedRecognitionMessageText(
              key: ValueKey<String>(message.id),
              text: message.original,
              isFinal: message.isFinal,
              textAlign: isPrimaryStyled ? TextAlign.right : TextAlign.left,
              style: bodyStyle,
            )
          : _InlineGroupedRecognitionText(
              messageId: message.id,
              groups: message.groups,
              isFinal: message.isFinal,
              textForGroup: (group) => group.original,
              keySuffix: 'orig',
              alignRight: isPrimaryStyled,
              style: bodyStyle,
            ),
    );

    return Column(
      crossAxisAlignment: isPrimaryStyled
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: _originalToggleDuration,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Align(
              alignment: contentAlignment,
              child: Column(
                crossAxisAlignment: isPrimaryStyled
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [...previousChildren, ?currentChild],
              ),
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: !shouldCollapseOriginal || showOriginal
              ? KeyedSubtree(
                  key: ValueKey<String>('${message.id}_original_visible'),
                  child: originalContent,
                )
              : SizedBox(
                  key: ValueKey<String>('${message.id}_original_hidden'),
                ),
        ),
        if (translationText != null) ...[
          const SizedBox(height: 10),
          expandToBubbleWidth(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      message.groups.any((group) => group.translation != null)
                      ? _InlineGroupedRecognitionText(
                          messageId: message.id,
                          groups: message.groups,
                          isFinal: message.isFinal,
                          textForGroup: (group) => group.translation,
                          keySuffix: 'translation',
                          alignRight: isPrimaryStyled,
                          style: translationStyle,
                        )
                      : _AnimatedRecognitionMessageText(
                          key: ValueKey<String>('${message.id}_translation'),
                          text: translationText,
                          isFinal: message.isFinal,
                          textAlign: isPrimaryStyled
                              ? TextAlign.right
                              : TextAlign.left,
                          style: translationStyle,
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey<String>('${message.id}_replay_translation'),
                  tooltip: l10n.replayTranslation,
                  icon: const Icon(Icons.replay_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.replayTranslation(message);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String? _resolvedTranslationText(ChatMessage message) {
    final directTranslation = message.translation?.trim();
    if (directTranslation != null && directTranslation.isNotEmpty) {
      return directTranslation;
    }

    final groupedTranslation = message.groups
        .map((group) => group.translation?.trim())
        .whereType<String>()
        .where((translation) => translation.isNotEmpty)
        .join(' ')
        .trim();
    return groupedTranslation.isEmpty ? null : groupedTranslation;
  }
}

class _AnimatedRecognitionMessageText extends StatefulWidget {
  final String text;
  final bool isFinal;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _AnimatedRecognitionMessageText({
    super.key,
    required this.text,
    required this.isFinal,
    required this.style,
    this.textAlign,
  });

  @override
  State<_AnimatedRecognitionMessageText> createState() =>
      _AnimatedRecognitionMessageTextState();
}

class _AnimatedPartialMessageText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _AnimatedPartialMessageText({
    required this.text,
    required this.style,
    this.textAlign,
  });

  @override
  State<_AnimatedPartialMessageText> createState() =>
      _AnimatedPartialMessageTextState();
}

class _AnimatedRecognitionMessageTextState
    extends State<_AnimatedRecognitionMessageText> {
  static const Duration _fadeDuration = Duration(seconds: 1);
  static const double _partialOpacity = 0.7;
  static const double _startingOpacity = 0.7;
  double _currentOpacity = _startingOpacity;
  double _targetOpacity = _startingOpacity;

  double _resolveTargetOpacity() {
    return widget.isFinal ? 1.0 : _partialOpacity;
  }

  @override
  void initState() {
    super.initState();
    _targetOpacity = _resolveTargetOpacity();
  }

  @override
  void didUpdateWidget(covariant _AnimatedRecognitionMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextOpacity = _resolveTargetOpacity();
    if (_targetOpacity == nextOpacity) return;
    setState(() {
      _currentOpacity = _targetOpacity;
      _targetOpacity = nextOpacity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.isFinal
        ? Text(widget.text, style: widget.style, textAlign: widget.textAlign)
        : _AnimatedPartialMessageText(
            text: widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          );

    return TweenAnimationBuilder<double>(
      duration: _fadeDuration,
      curve: Curves.easeOut,
      tween: Tween<double>(begin: _currentOpacity, end: _targetOpacity),
      builder: (context, animatedOpacity, _) {
        return Opacity(opacity: animatedOpacity, child: child);
      },
    );
  }
}

class _AnimatedPartialMessageTextState
    extends State<_AnimatedPartialMessageText>
    with SingleTickerProviderStateMixin {
  static const Duration _gradientDuration = Duration(milliseconds: 1400);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _gradientDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final baseColor =
        resolvedStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final highlightColor = Color.lerp(
      baseColor,
      baseColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
      0.28,
    )!;
    final trailingColor = baseColor.withValues(
      alpha: (baseColor.a * 0.55).clamp(0.0, 1.0),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: Text(widget.text, style: resolvedStyle, textAlign: widget.textAlign),
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            final height = bounds.height <= 0 ? 1.0 : bounds.height;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [trailingColor, highlightColor, trailingColor],
              stops: const [0.2, 0.5, 0.8],
              transform: _SlidingTextGradientTransform(
                progress: _controller.value,
              ),
            ).createShader(Rect.fromLTWH(-width, 0, width * 3, height));
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingTextGradientTransform extends GradientTransform {
  final double progress;

  const _SlidingTextGradientTransform({required this.progress});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translate(bounds.width * (progress * 2 - 1));
  }
}

class _InlineGroupedRecognitionText extends StatelessWidget {
  final String messageId;
  final List<ChatMessageGroup> groups;
  final bool isFinal;
  final String? Function(ChatMessageGroup group) textForGroup;
  final String keySuffix;
  final bool alignRight;
  final TextStyle? style;

  const _InlineGroupedRecognitionText({
    required this.messageId,
    required this.groups,
    required this.isFinal,
    required this.textForGroup,
    required this.keySuffix,
    required this.alignRight,
    required this.style,
  });

  bool _hasTerminalPunctuation(String text) {
    return RegExp(r'[.!?]$').hasMatch(text.trimRight());
  }

  @override
  Widget build(BuildContext context) {
    final entries = <({ChatMessageGroup group, String text, int index})>[];
    for (var i = 0; i < groups.length; i++) {
      final text = textForGroup(groups[i]);
      if (text == null) continue;
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      entries.add((group: groups[i], text: trimmed, index: i));
    }

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestIndex = entries.last.index;
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final segmentIsFinal = isFinal || entry.index < latestIndex;
      if (i > 0) {
        final previousText = entries[i - 1].text;
        final separator = _hasTerminalPunctuation(previousText) ? ' ' : ', ';
        children.add(Text(separator, style: style));
      }

      if (!segmentIsFinal) {
        children.add(
          _AnimatedRecognitionMessageText(
            key: ValueKey<String>(
              '${messageId}_group_${entry.group.id}_${keySuffix}_partial',
            ),
            text: entry.text,
            isFinal: false,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: style,
          ),
        );
        continue;
      }

      final words = entry.text
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList(growable: false);
      for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
        children.add(
          _AnimatedRecognitionMessageText(
            key: ValueKey<String>(
              '${messageId}_group_${entry.group.id}_${keySuffix}_w$wordIndex',
            ),
            text: words[wordIndex],
            isFinal: true,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: style,
          ),
        );
        if (wordIndex < words.length - 1) {
          children.add(Text(' ', style: style));
        }
      }
    }

    return Wrap(
      alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: children,
    );
  }
}
