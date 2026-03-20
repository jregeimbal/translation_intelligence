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

## Containerization

The backend now includes a compiled-binary container build in
`server/Dockerfile`.

### Build approach

- builder stage: official Dart SDK image
- build output: `dart compile exe bin/server.dart`
- runtime stage: slim Debian image with CA certificates
- runtime process: `/app/server`

This keeps the production image smaller and avoids starting the service through
`dart run`.

### Files

- `server/Dockerfile`
- `server/.dockerignore`

The `.dockerignore` excludes tests, Dart build state, and local credential JSON
files so they are not copied into the container build context.

### Build the container locally

```bash
docker build -t translation-intelligence-server ./server
```

### Run the container locally

```bash
docker run --rm -p 8080:8080 \
  -e FIREBASE_PROJECT_ID="your-firebase-project-id" \
  -e FIREBASE_WEB_API_KEY="your-firebase-web-api-key" \
  -e DEEPGRAM_API_KEY="your-deepgram-api-key" \
  -e GOOGLE_SERVICE_ACCOUNT_JSON="$(cat /absolute/path/to/service-account.json)" \
  -e ALLOWED_ORIGINS="http://localhost:3000,http://localhost:8000" \
  translation-intelligence-server
```

If you prefer a mounted secret file instead of inline JSON:

```bash
docker run --rm -p 8080:8080 \
  -e FIREBASE_PROJECT_ID="your-firebase-project-id" \
  -e FIREBASE_WEB_API_KEY="your-firebase-web-api-key" \
  -e DEEPGRAM_API_KEY="your-deepgram-api-key" \
  -e GOOGLE_SERVICE_ACCOUNT_JSON_PATH="/run/secrets/service-account.json" \
  -v /absolute/path/to/service-account.json:/run/secrets/service-account.json:ro \
  translation-intelligence-server
```

Then verify:

```bash
curl http://localhost:8080/v1/health
```

Or run the smoke test helper:

```bash
API_BASE_URL=http://localhost:8080 EXPECT_AUTH_SUCCESS=false tool/smoke_test_server.sh
```

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

For Cloud Run, prefer `GOOGLE_SERVICE_ACCOUNT_JSON` as a secret-backed
environment variable instead of baking a JSON file into the image.

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

## Deploying to Cloud Run

### 1. Build and push with Cloud Build

```bash
gcloud builds submit ./server \
  --tag us-central1-docker.pkg.dev/PROJECT_ID/REPOSITORY/translation-intelligence-server:latest
```

Or use the checked-in build config:

```bash
gcloud builds submit ./server \
  --config server/cloudbuild.yaml \
  --substitutions _REGION=us-central1,_REPOSITORY=translation-intelligence,_IMAGE_NAME=translation-intelligence-server,_TAG=latest
```

### 2. Deploy the image to Cloud Run

```bash
gcloud run deploy translation-intelligence-server \
  --image us-central1-docker.pkg.dev/PROJECT_ID/REPOSITORY/translation-intelligence-server:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "^@^ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com@HTTP_RATE_LIMIT_PER_MINUTE=120@WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE=30@FIREBASE_PROJECT_ID=your-project-id" \
  --set-secrets FIREBASE_WEB_API_KEY=FIREBASE_WEB_API_KEY:latest,DEEPGRAM_API_KEY=DEEPGRAM_API_KEY:latest,GOOGLE_SERVICE_ACCOUNT_JSON=GOOGLE_SERVICE_ACCOUNT_JSON:latest
```

Or use the reusable deploy helper:

```bash
GCP_PROJECT_ID=your-gcp-project-id \
ARTIFACT_REPOSITORY=translation-intelligence \
ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com \
FIREBASE_PROJECT_ID=your-firebase-project-id \
tool/deploy_server_cloud_run.sh
```

Files:

- `server/cloudbuild.yaml`
- `tool/deploy_server_cloud_run.sh`

Notes:

- Replace `PROJECT_ID`, `REPOSITORY`, and region values with your own
- The custom `^@^...@...` delimiter keeps the comma-separated `ALLOWED_ORIGINS`
  value intact
- Keep `FIREBASE_WEB_API_KEY`, `DEEPGRAM_API_KEY`, and
  `GOOGLE_SERVICE_ACCOUNT_JSON` in Secret Manager
- `--allow-unauthenticated` is appropriate here because the app authenticates at
  the application layer with Firebase tokens; if you later put the service
  behind another edge layer, revisit this choice

### 3. Recommended Cloud Run settings

- health path: `/v1/health`
- request timeout: long enough for live STT sessions
- minimum instances: optional, set above zero only if cold starts matter
- concurrency: start with the default, then tune based on WebSocket load and
  memory usage

### 4. Post-deploy smoke tests

```bash
curl https://YOUR_SERVICE_URL/v1/health
```

```bash
curl \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
  https://YOUR_SERVICE_URL/v1/capabilities
```

Or use the reusable helper:

```bash
API_BASE_URL=https://YOUR_SERVICE_URL FIREBASE_ID_TOKEN=$FIREBASE_ID_TOKEN tool/smoke_test_server.sh
```

Smoke test behavior:

- always validates `/v1/health`
- validates authenticated `/v1/capabilities` when `FIREBASE_ID_TOKEN` is set
- can verify the unauthenticated `401` path with `EXPECT_AUTH_SUCCESS=false`

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

### Container starts but exits immediately

Check:

- required env vars are present in Cloud Run
- secrets are mapped to the correct environment variable names
- the deployed revision logs show successful startup on `PORT`

## Security note

Do not bake service-account JSON files or API keys into the image. Keep them in
Secret Manager or inject them only at runtime.

## Source of truth in code

- `server/bin/server.dart`
- `server/lib/src/config/app_config.dart`
- `server/lib/src/http/api_server.dart`
- `server/lib/src/http/middleware.dart`
