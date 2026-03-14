import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/theme/app_theme_resolver.dart';

class ChatMessage {
  static int _nextMessageId = 0;

  final String id;
  String original;
  bool isFinal;
  String? translation;
  final DateTime timestamp;

  /// Optional speaker ID assigned by Deepgram.  `null` indicates unknown.
  final int? speaker;

  ChatMessage(
    this.original, {
    this.speaker,
    this.isFinal = false,
    String? id,
    DateTime? timestamp,
  }) : id = id ?? 'msg_${_nextMessageId++}',
       timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    if (speaker != null) {
      return 'Speaker ${speaker! + 1}: $original';
    }
    return original;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      json['original'] as String,
      speaker: json['speaker'] as int?,
      isFinal: json['isFinal'] as bool? ?? false,
      id: json['id'] as String?,
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    )..translation = json['translation'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'speaker': speaker,
      'isFinal': isFinal,
      'translation': translation,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

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
          ? 'Listening...'
          : (speechEnabled
                ? 'Tap the mic to start listening...'
                : 'Speech not available');
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
            final textColor = theme.colorScheme.onSurface;
            final speakerChipColor = _speakerChipBackground(
              msg.speaker,
              isPreferred,
              tokens,
              theme,
            );

            return Align(
              alignment: isPreferred
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.88,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                              'Speaker ${msg.speaker! + 1}',
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
                    const SizedBox(height: 8),
                    _AnimatedRecognitionMessageText(
                      key: ValueKey<String>(msg.id),
                      text: msg.original,
                      isFinal: msg.isFinal,
                      style: textRoles.bubbleBody.copyWith(color: textColor),
                    ),
                    if (msg.translation != null) ...[
                      const SizedBox(height: 10),
                      _AnimatedRecognitionMessageText(
                        key: ValueKey<String>('${msg.id}_translation'),
                        text: msg.translation!,
                        isFinal: msg.isFinal,
                        style: textRoles.bubbleTranslation.copyWith(
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
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
                label: const Text('Jump to latest'),
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

class _AnimatedRecognitionMessageText extends StatefulWidget {
  final String text;
  final bool isFinal;
  final TextStyle? style;

  const _AnimatedRecognitionMessageText({
    super.key,
    required this.text,
    required this.isFinal,
    required this.style,
  });

  @override
  State<_AnimatedRecognitionMessageText> createState() =>
      _AnimatedRecognitionMessageTextState();
}

class _AnimatedPartialMessageText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _AnimatedPartialMessageText({required this.text, required this.style});

  @override
  State<_AnimatedPartialMessageText> createState() =>
      _AnimatedPartialMessageTextState();
}

class _AnimatedRecognitionMessageTextState
    extends State<_AnimatedRecognitionMessageText> {
  static const Duration _fadeDuration = Duration(seconds: 1);
  static const double _partialOpacity = 0.6;
  static const double _startingOpacity = 0.2;
  double _currentOpacity = _startingOpacity;
  double _targetOpacity = _startingOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _targetOpacity = widget.isFinal ? 1.0 : _partialOpacity;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedRecognitionMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextOpacity = widget.isFinal ? 1.0 : _partialOpacity;
    if (_targetOpacity == nextOpacity) return;
    setState(() {
      _currentOpacity = _targetOpacity;
      _targetOpacity = nextOpacity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.isFinal
        ? Text(widget.text, style: widget.style)
        : _AnimatedPartialMessageText(text: widget.text, style: widget.style);

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
    extends State<_AnimatedPartialMessageText> {
  static const Duration _tick = Duration(milliseconds: 320);
  late final Timer _timer;
  int _activeDotIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() {
        _activeDotIndex = (_activeDotIndex + 1) % 3;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final baseColor =
        resolvedStyle.color ?? Theme.of(context).colorScheme.onSurface;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.text),
          for (var index = 0; index < 3; index++)
            TextSpan(
              text: '.',
              style: resolvedStyle.copyWith(
                color: baseColor.withValues(
                  alpha: index == _activeDotIndex ? 1.0 : 0.35,
                ),
              ),
            ),
        ],
      ),
      style: resolvedStyle,
    );
  }
}
