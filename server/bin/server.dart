import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'package:translation_intelligence_server/src/config/app_config.dart';
import 'package:translation_intelligence_server/src/http/api_server.dart';

Future<void> main() async {
  _configureLogging();

  final config = AppConfig.fromEnvironment();
  final apiServer = ApiServer.fromConfig(config);
  final server = await apiServer.start();

  Logger(
    'Server',
  ).info('Listening on http://${server.address.host}:${server.port}');

  Future<void> shutdown() async {
    Logger('Server').info('Shutting down');
    await apiServer.close();
    await server.close(force: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
  ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
}

void _configureLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    final message = record.message;
    if (_looksLikeJson(message)) {
      stderr.writeln(message);
      return;
    }

    stderr.writeln(
      jsonEncode({
        'timestamp': record.time.toIso8601String(),
        'severity': record.level.name,
        'logger': record.loggerName,
        'message': message,
        if (record.error != null) 'error': '${record.error}',
      }),
    );
  });
}

bool _looksLikeJson(String message) {
  final trimmed = message.trimLeft();
  return trimmed.startsWith('{') && trimmed.endsWith('}');
}
