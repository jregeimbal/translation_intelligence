# Server Deployment

This document covers local backend startup, required environment variables,
Firebase setup, and the current Cloud Run deployment expectations for the Dart
API in `server/`.

## What the server does

The backend exposes:

- `GET /v1/health`
- `GET /v1/capabilities`
- `POST /v1/translate`
- `POST /v1/tts`
- `WS /v1/stt/live`

It authenticates distributed clients with Firebase ID tokens, keeps vendor
credentials on the server side, and adds request tracing, structured logging,
per-instance rate limiting, and WebSocket metrics suitable for Cloud Run.

For request and response details, see `docs/server-api.md`.

## Prerequisites

- Dart SDK compatible with `server/pubspec.yaml`
- A Firebase project with Anonymous Auth enabled
- A Firebase Web API key for the same project
- A Google Cloud service account with Translation and Text-to-Speech access
- A Deepgram API key

## Local development

### 1. Install dependencies

```bash
cd server
dart pub get
```

### 2. Export environment variables

Minimum required configuration:

```bash
export FIREBASE_PROJECT_ID="your-firebase-project-id"
export FIREBASE_WEB_API_KEY="your-firebase-web-api-key"
export DEEPGRAM_API_KEY="your-deepgram-api-key"
export GOOGLE_SERVICE_ACCOUNT_JSON_PATH="/absolute/path/to/service-account.json"
```

Optional server settings:

```bash
export SERVER_HOST="0.0.0.0"
export PORT="8080"
export ALLOWED_ORIGINS="http://localhost:3000,http://localhost:8000"
export HTTP_RATE_LIMIT_PER_MINUTE="120"
export WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE="30"
```

### 3. Start the server

```bash
cd server
dart run bin/server.dart
```

By default, the server listens on `0.0.0.0:8080` unless `PORT` is overridden.

## Environment variables

The server reads configuration from `server/lib/src/config/app_config.dart`.

### Required

- `FIREBASE_PROJECT_ID` - Firebase project used to verify client tokens
- `FIREBASE_WEB_API_KEY` - Firebase Web API key used by the auth verifier
- `DEEPGRAM_API_KEY` - used for backend STT and Deepgram TTS
- `GOOGLE_SERVICE_ACCOUNT_JSON` or `GOOGLE_SERVICE_ACCOUNT_JSON_PATH` - Google
  service account credentials used for Translation and Google TTS

### Optional

- `SERVER_HOST` - defaults to `0.0.0.0`
- `PORT` - defaults to `8080`
- `ALLOWED_ORIGINS` - comma-separated list, defaults to `http://localhost:8000`
- `HTTP_RATE_LIMIT_PER_MINUTE` - defaults to `120`
- `WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE` - defaults to `30`

## Service account options

You can provide Google credentials in either of these forms:

### Inline JSON

```bash
export GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

### File path

```bash
export GOOGLE_SERVICE_ACCOUNT_JSON_PATH="/secrets/service-account.json"
```

For local development, `GOOGLE_SERVICE_ACCOUNT_JSON_PATH` is usually easier.
For managed deployments, inline secret injection can be simpler.

## Firebase setup

The backend expects Firebase ID tokens issued by the same Firebase project used
by the client app.

### Enable Anonymous Auth

In Firebase Console:

1. Open Authentication
2. Open Sign-in method
3. Enable Anonymous

### Pass the correct project values to the server

The backend must use:

- the Firebase project ID in `FIREBASE_PROJECT_ID`
- the matching Firebase Web API key in `FIREBASE_WEB_API_KEY`

If these do not match the client project, bearer token verification and STT
session startup will fail.

## Flutter app configuration

Point the app at the backend with:

```bash
API_BASE_URL=https://your-api.example.com
```

The Flutter app uses Firebase Anonymous Auth client-side, gets an ID token, and
sends it to the backend as:

- an HTTP bearer token for REST requests
- the `token` field in the WebSocket STT `start` message

## Cloud Run guidance

The server is designed for Cloud Run-style operation:

- listens on `PORT`
- logs structured JSON to stderr
- emits request IDs and Cloud Trace correlation data
- uses in-memory per-instance rate limiting and metrics

### Recommended runtime configuration

- Set `PORT=8080` unless your deployment platform injects it automatically
- Set `ALLOWED_ORIGINS` to your production web origins
- Inject secrets instead of baking them into an image
- Restrict service account access to only the required Google APIs

### Recommended secret handling

Prefer secret injection for:

- `DEEPGRAM_API_KEY`
- `FIREBASE_WEB_API_KEY`
- `GOOGLE_SERVICE_ACCOUNT_JSON`

If you mount a file instead, use `GOOGLE_SERVICE_ACCOUNT_JSON_PATH`.

### Deployment checklist

- Firebase Anonymous Auth enabled
- `FIREBASE_PROJECT_ID` matches the client app project
- `FIREBASE_WEB_API_KEY` matches the same Firebase project
- `DEEPGRAM_API_KEY` present
- Google service account credentials present
- `ALLOWED_ORIGINS` includes every browser origin that should call the API
- Health check path configured as `/v1/health`

### Example Cloud Run environment set

```text
PORT=8080
ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com
HTTP_RATE_LIMIT_PER_MINUTE=120
WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE=30
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_WEB_API_KEY=[secret]
DEEPGRAM_API_KEY=[secret]
GOOGLE_SERVICE_ACCOUNT_JSON=[secret]
```

## Health checks and smoke tests

After deployment, verify:

### Health

```bash
curl https://your-api.example.com/v1/health
```

Expected response:

```json
{
  "status": "ok"
}
```

### Authenticated capability check

```bash
curl \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
  https://your-api.example.com/v1/capabilities
```

## Troubleshooting

### Missing Google credential configuration

If startup fails with a message about missing Google service account variables,
set either:

- `GOOGLE_SERVICE_ACCOUNT_JSON`
- `GOOGLE_SERVICE_ACCOUNT_JSON_PATH`

### Unauthorized responses

Check:

- the client is signed in anonymously with Firebase
- the token comes from the same Firebase project
- `FIREBASE_PROJECT_ID` and `FIREBASE_WEB_API_KEY` are correct on the server

### Browser CORS failures

Check that the exact frontend origin is included in `ALLOWED_ORIGINS`.

### STT WebSocket startup failures

Check:

- the first WebSocket message is a `start` JSON payload
- the payload includes `token`, `sourceLanguage`, and `sampleRate`
- the client streams PCM16 mono audio frames after receiving `ready`

## Source of truth in code

- `server/bin/server.dart`
- `server/lib/src/config/app_config.dart`
- `server/lib/src/http/api_server.dart`
- `server/lib/src/http/middleware.dart`
