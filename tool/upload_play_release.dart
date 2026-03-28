import 'dart:convert';
import 'dart:io';

import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:googleapis_auth/auth_io.dart';

const _defaultApiBaseUrl =
    'https://omnialingo-server-633223066396.us-central1.run.app/';
const _defaultPackageName = 'com.jax3.omnialingo';
const _defaultTrack = 'internal';
const _defaultReleaseStatus = 'draft';
const _defaultBundlePath = 'build/app/outputs/bundle/release/app-release.aab';
const _androidPublisherScope =
    'https://www.googleapis.com/auth/androidpublisher';

Future<void> main(List<String> arguments) async {
  final config = _ReleaseConfig.fromEnvironment(
    arguments,
    Platform.environment,
  );
  if (config.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final bundleFile = File(config.bundlePath);
  AuthClient? authClient;
  String? editId;

  try {
    if (!config.skipBuild) {
      await _runFlutterBuild(config);
    }

    if (!bundleFile.existsSync()) {
      throw StateError(
        'Android App Bundle not found at ${bundleFile.path}. '
        'Build the app first or pass --aab-path.',
      );
    }

    final serviceAccountJson = _loadServiceAccountJson(config);
    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    authClient = await clientViaServiceAccount(credentials, const <String>[
      _androidPublisherScope,
    ]);

    final api = play.AndroidPublisherApi(authClient);
    final edit = await api.edits.insert(play.AppEdit(), config.packageName);
    editId = edit.id;
    if (editId == null || editId.isEmpty) {
      throw StateError('Google Play returned an empty edit id.');
    }

    stdout.writeln('Created Play edit $editId for ${config.packageName}.');

    final upload = await api.edits.bundles.upload(
      config.packageName,
      editId,
      uploadMedia: play.Media(
        bundleFile.openRead(),
        bundleFile.lengthSync(),
        contentType: 'application/octet-stream',
      ),
    );

    final versionCode = upload.versionCode;
    if (versionCode == null) {
      throw StateError('Google Play did not return a versionCode for the AAB.');
    }

    stdout.writeln(
      'Uploaded ${bundleFile.path} as versionCode $versionCode '
      '(sha1: ${upload.sha1 ?? 'n/a'}).',
    );

    final appliedReleaseStatus = await _publishEdit(
      api: api,
      config: config,
      editId: editId,
      versionCode: versionCode,
    );
    editId = null;

    stdout.writeln(
      'Committed Play edit for ${config.packageName} on track ${config.track} '
      'with release status $appliedReleaseStatus.',
    );
  } on ProcessException catch (error) {
    stderr.writeln('Command failed: ${error.message}');
    exitCode = error.errorCode;
  } on Exception catch (error) {
    stderr.writeln('Google Play API request failed: $error');
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    if (authClient != null && editId != null) {
      try {
        final api = play.AndroidPublisherApi(authClient);
        await api.edits.delete(config.packageName, editId);
      } on Object {
        // Best effort cleanup only.
      }
    }
    authClient?.close();
  }
}

Future<String> _publishEdit({
  required play.AndroidPublisherApi api,
  required _ReleaseConfig config,
  required String editId,
  required int versionCode,
}) async {
  var releaseStatus = config.releaseStatus;

  await _removeExistingDraftReleases(api: api, config: config, editId: editId);

  try {
    await _updateTrack(
      api: api,
      config: config,
      editId: editId,
      releaseStatus: releaseStatus,
      versionCode: versionCode,
    );
  } on Object catch (error) {
    if (!_shouldRetryAsDraft(config: config, error: error)) {
      rethrow;
    }

    releaseStatus = 'draft';
    stdout.writeln(
      'Google Play rejected release status ${config.releaseStatus} for a draft '
      'app. Retrying with release status draft.',
    );
    await _updateTrack(
      api: api,
      config: config,
      editId: editId,
      releaseStatus: releaseStatus,
      versionCode: versionCode,
    );
  }

  if (config.validateOnly) {
    await api.edits.validate(config.packageName, editId);
    stdout.writeln(
      'Validated Play edit $editId for track ${config.track}; edit not committed.',
    );
    return releaseStatus;
  }

  await api.edits.commit(
    config.packageName,
    editId,
    changesNotSentForReview: config.changesNotSentForReview,
  );

  return releaseStatus;
}

Future<void> _removeExistingDraftReleases({
  required play.AndroidPublisherApi api,
  required _ReleaseConfig config,
  required String editId,
}) async {
  play.Track existingTrack;

  try {
    existingTrack = await api.edits.tracks.get(
      config.packageName,
      editId,
      config.track,
    );
  } on Object {
    return;
  }

  final releases = existingTrack.releases;
  if (releases == null || releases.isEmpty) {
    return;
  }

  final retainedReleases = releases
      .where((release) => (release.status ?? '').toLowerCase() != 'draft')
      .toList();
  if (retainedReleases.length == releases.length) {
    return;
  }

  stdout.writeln(
    'Removing ${releases.length - retainedReleases.length} existing draft '
    'release(s) from track ${config.track} before upload.',
  );

  await api.edits.tracks.update(
    play.Track(track: config.track, releases: retainedReleases),
    config.packageName,
    editId,
    config.track,
  );
}

Future<void> _updateTrack({
  required play.AndroidPublisherApi api,
  required _ReleaseConfig config,
  required String editId,
  required String releaseStatus,
  required int versionCode,
}) {
  stdout.writeln('Update request for track ${config.track} with release status $releaseStatus, release name ${config.releaseName} and version code $versionCode');
  return api.edits.tracks.update(
    play.Track(
      track: config.track,
      releases: <play.TrackRelease>[
        play.TrackRelease(
          name: config.releaseName,
          status: releaseStatus,
          versionCodes: <String>[versionCode.toString()],
        ),
      ],
    ),
    config.packageName,
    editId,
    config.track,
  );
}

bool _shouldRetryAsDraft({
  required _ReleaseConfig config,
  required Object error,
}) {
  if (config.isReleaseStatusExplicit || config.releaseStatus == 'draft') {
    return false;
  }

  final message = error.toString().toLowerCase();
  return message.contains(
    'only releases with status draft may be created on draft app',
  );
}

Future<void> _runFlutterBuild(_ReleaseConfig config) async {
  final command = <String>[
    'flutter',
    'build',
    'appbundle',
    '--release',
    '--dart-define=NO_DOTENV_OVERRIDE=${config.noDotenvOverride}',
    '--dart-define=API_BASE_URL=${config.apiBaseUrl}',
  ];

  stdout.writeln('Running: ${command.join(' ')}');

  final result = await Process.start(
    command.first,
    command.sublist(1),
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      command.first,
      command.sublist(1),
      'flutter build failed',
      exitCode,
    );
  }
}

Map<String, dynamic> _loadServiceAccountJson(_ReleaseConfig config) {
  final inlineJson = config.serviceAccountJson;
  if (inlineJson != null && inlineJson.isNotEmpty) {
    final decoded = jsonDecode(inlineJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw StateError('Service account JSON must decode to an object.');
  }

  final jsonPath = config.serviceAccountJsonPath;
  if (jsonPath == null || jsonPath.isEmpty) {
    throw StateError(
      'Missing Google Play credentials. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH '
      'or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.',
    );
  }

  final file = File(jsonPath);
  if (!file.existsSync()) {
    throw StateError('Service account JSON file not found at $jsonPath.');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw StateError('Service account JSON file must decode to an object.');
}

class _ReleaseConfig {
  _ReleaseConfig({
    required this.apiBaseUrl,
    required this.bundlePath,
    required this.changesNotSentForReview,
    required this.noDotenvOverride,
    required this.packageName,
    required this.releaseName,
    required this.releaseStatus,
    required this.isReleaseStatusExplicit,
    required this.serviceAccountJson,
    required this.serviceAccountJsonPath,
    required this.showHelp,
    required this.skipBuild,
    required this.track,
    required this.validateOnly,
  });

  factory _ReleaseConfig.fromEnvironment(
    List<String> arguments,
    Map<String, String> environment,
  ) {
    final options = _parseArgs(arguments);
    final pubspecVersion = _readPubspecVersion();
    final isReleaseStatusExplicit =
        options.containsKey('release-status') ||
        environment.containsKey('PLAY_RELEASE_STATUS');

    return _ReleaseConfig(
      apiBaseUrl:
          options['api-base-url'] ??
          environment['API_BASE_URL'] ??
          _defaultApiBaseUrl,
      bundlePath:
          options['aab-path'] ??
          environment['PLAY_AAB_PATH'] ??
          _defaultBundlePath,
      changesNotSentForReview: _readBool(
        options['changes-not-sent-for-review'] ??
            environment['PLAY_CHANGES_NOT_SENT_FOR_REVIEW'],
      ),
      noDotenvOverride:
          options['no-dotenv-override'] ??
          environment['NO_DOTENV_OVERRIDE'] ??
          'true',
      packageName:
          options['package-name'] ??
          environment['PLAY_PACKAGE_NAME'] ??
          _defaultPackageName,
      releaseName:
          options['release-name'] ??
          environment['PLAY_RELEASE_NAME'] ??
          pubspecVersion,
      releaseStatus:
          options['release-status'] ??
          environment['PLAY_RELEASE_STATUS'] ??
          _defaultReleaseStatus,
      isReleaseStatusExplicit: isReleaseStatusExplicit,
      serviceAccountJson:
          options['service-account-json'] ??
          environment['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'] ??
          environment['GOOGLE_SERVICE_ACCOUNT_JSON'],
      serviceAccountJsonPath:
          options['service-account-json-path'] ??
          environment['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH'] ??
          environment['GOOGLE_SERVICE_ACCOUNT_JSON_PATH'],
      showHelp: options.containsKey('help'),
      skipBuild: options.containsKey('skip-build'),
      track: options['track'] ?? environment['PLAY_TRACK'] ?? _defaultTrack,
      validateOnly: options.containsKey('validate-only'),
    );
  }

  final String apiBaseUrl;
  final String bundlePath;
  final bool changesNotSentForReview;
  final String noDotenvOverride;
  final String packageName;
  final String releaseName;
  final String releaseStatus;
  final bool isReleaseStatusExplicit;
  final String? serviceAccountJson;
  final String? serviceAccountJsonPath;
  final bool showHelp;
  final bool skipBuild;
  final String track;
  final bool validateOnly;
}

Map<String, String?> _parseArgs(List<String> arguments) {
  final options = <String, String?>{};

  for (final argument in arguments) {
    if (!argument.startsWith('--')) {
      throw ArgumentError('Unsupported positional argument: $argument');
    }

    final trimmed = argument.substring(2);
    final separatorIndex = trimmed.indexOf('=');
    if (separatorIndex == -1) {
      options[trimmed] = null;
      continue;
    }

    options[trimmed.substring(0, separatorIndex)] = trimmed.substring(
      separatorIndex + 1,
    );
  }

  return options;
}

String _readPubspecVersion() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    return 'release';
  }

  final content = pubspecFile.readAsStringSync();
  final match = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(content);
  return match?.group(1) ?? 'release';
}

bool _readBool(String? value) {
  if (value == null) {
    return false;
  }

  switch (value.toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'y':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'n':
      return false;
    default:
      throw ArgumentError('Expected a boolean value, got "$value".');
  }
}

const _usage = '''
Build the Android App Bundle and upload it to Google Play with the Android Publisher API.

Usage:
  dart run tool/upload_play_release.dart [options]

Options:
  --help
  --skip-build
  --validate-only
  --package-name=<applicationId>
  --track=<internal|alpha|beta|production>
  --release-status=<draft|completed|inProgress|halted>
  --release-name=<name>
  --aab-path=<path>
  --api-base-url=<url>
  --no-dotenv-override=<true|false>
  --service-account-json-path=<path>
  --service-account-json=<json>
  --changes-not-sent-for-review=<true|false>

Environment fallbacks:
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
  PLAY_PACKAGE_NAME
  PLAY_TRACK
  PLAY_RELEASE_STATUS
  PLAY_RELEASE_NAME
  PLAY_AAB_PATH
  PLAY_CHANGES_NOT_SENT_FOR_REVIEW
  API_BASE_URL
  NO_DOTENV_OVERRIDE

Defaults:
  package name: com.jax3.omnialingo
  track: internal
  release status: draft
''';
