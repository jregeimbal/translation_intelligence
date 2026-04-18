import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/two_way_chat_controller.dart';
import 'two_way_chat.dart';

/// The two-way chat body with language selection and message view.
class TwoWayChatBody extends StatelessWidget {
  const TwoWayChatBody({
    super.key,
    required this.initializing,
    required this.twoWayController,
  });

  final bool initializing;
  final TwoWayChatController twoWayController;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('two_way_placeholder'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12),
        child: initializing
            ? const Center(child: CircularProgressIndicator())
            : ChangeNotifierProvider<TwoWayChatController>.value(
                value: twoWayController,
                child: const TwoWayChatView(),
              ),
      ),
    );
  }
}
