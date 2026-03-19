# Server API

This project ships a Dart backend in `server/` that fronts cloud translation,
text-to-speech, and live speech-to-text. The mobile/web app authenticates with
Firebase Anonymous Auth and talks to this API instead of embedding vendor
credentials in the client.

## Overview

- Base path: `/v1`
- HTTP auth: `Authorization: Bearer <firebase_id_token>`
- WebSocket auth: first message must be a `start` payload containing `token`
- HTTP content types: JSON requests, JSON responses, except TTS audio responses
- STT transport: WebSocket at `/v1/stt/live`

## Current capabilities

The backend currently exposes these provider capabilities:

- Translation providers: `google`
- TTS providers: `google`, `deepgram`
- STT providers: `deepgram`, `google`

The discovery endpoint returns the same values at runtime.

## Authentication

### HTTP endpoints

These endpoints are public:

- `GET /v1/health`

These endpoints require a Firebase bearer token:

- `GET /v1/capabilities`
- `POST /v1/translate`
- `POST /v1/tts`

### WebSocket endpoint

`/v1/stt/live` does not use the HTTP bearer auth middleware. Instead, the first
WebSocket message must be a JSON `start` payload that includes a Firebase ID
token in the `token` field.

## Endpoints

## Example clients

Set a few shell variables before using the HTTP examples:

```bash
export API_BASE_URL="https://your-api.example.com"
export FIREBASE_ID_TOKEN="your_firebase_id_token"
```

### `curl` health check

```bash
curl "$API_BASE_URL/v1/health"
```

### `curl` capabilities

```bash
curl \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
  "$API_BASE_URL/v1/capabilities"
```

### `curl` translate

```bash
curl \
  -X POST "$API_BASE_URL/v1/translate" \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, how are you?",
    "sourceLanguage": "en",
    "targetLanguage": "es"
  }'
```

### `curl` TTS

```bash
curl \
  -X POST "$API_BASE_URL/v1/tts" \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "deepgram",
    "text": "Bonjour",
    "languageCode": "fr-FR"
  }' \
  --output sample.mp3
```

### WebSocket STT with `wscat`

Install `wscat` if needed:

```bash
npm install -g wscat
```

Open a socket:

```bash
wscat -c "${API_BASE_URL/https/ws}/v1/stt/live"
```

Then send the initial start payload:

```json
{
  "type": "start",
  "token": "your_firebase_id_token",
  "sourceLanguage": "en-US",
  "sampleRate": 16000,
  "model": "nova-3",
  "language": "en",
  "diarize": false,
  "utterances": true,
  "punctuate": true,
  "smartFormat": true,
  "detectLanguage": false
}
```

`wscat` is useful for the handshake and control messages. For actual audio
streaming, use an application client that can send binary PCM frames.

### Minimal JavaScript WebSocket example

```js
const socket = new WebSocket('wss://your-api.example.com/v1/stt/live');

socket.addEventListener('open', () => {
  socket.send(JSON.stringify({
    type: 'start',
    token: firebaseIdToken,
    sourceLanguage: 'en-US',
    sampleRate: 16000,
    model: 'nova-3',
    language: 'en',
    diarize: false,
    utterances: true,
    punctuate: true,
    smartFormat: true,
    detectLanguage: false,
  }));

  // Send PCM16 mono audio chunks as ArrayBuffer/Uint8Array values.
  socket.send(pcmChunk);
  socket.send(JSON.stringify({ type: 'stop' }));
});

socket.addEventListener('message', (event) => {
  console.log('server message', event.data);
});
```

### `GET /v1/health`

Lightweight health check used for readiness/liveness.

Auth: none

Response:

```json
{
  "status": "ok"
}
```

### `GET /v1/capabilities`

Returns the currently configured backend capability matrix.

Auth: bearer token required

Response:

```json
{
  "translationProviders": ["google"],
  "ttsProviders": ["google", "deepgram"],
  "sttProviders": ["deepgram", "google"],
  "status": "ok"
}
```

### `POST /v1/translate`

Translates text through the backend translation provider.

Auth: bearer token required

Request body:

```json
{
  "text": "Hello, how are you?",
  "targetLanguage": "es",
  "sourceLanguage": "en"
}
```

Fields:

- `text` - required, non-empty string
- `targetLanguage` - required, non-empty string
- `sourceLanguage` - optional string

Response:

```json
{
  "translatedText": "Hola, como estas?",
  "targetLanguage": "es",
  "sourceLanguage": "en"
}
```

### `POST /v1/tts`

Synthesizes MP3 audio through the selected backend TTS provider.

Auth: bearer token required

Request body:

```json
{
  "provider": "deepgram",
  "text": "Bonjour",
  "languageCode": "fr-FR"
}
```

Fields:

- `provider` - required, one of `google` or `deepgram`
- `text` - required, non-empty string
- `languageCode` - required, non-empty string

Response:

- Status: `200 OK`
- Content-Type: `audio/mpeg`
- Body: raw MP3 bytes

### `WS /v1/stt/live`

Streams PCM audio to the backend and receives recognition results over a single
WebSocket session.

Auth: Firebase token in the first `start` message

#### Client -> server `start`

The first message must be JSON:

```json
{
  "type": "start",
  "token": "<firebase_id_token>",
  "sourceLanguage": "en-US",
  "sampleRate": 16000,
  "model": "nova-3",
  "language": "en",
  "diarize": false,
  "utterances": true,
  "punctuate": true,
  "smartFormat": true,
  "detectLanguage": false
}
```

Fields:

- `type` - must be `start`
- `token` - required Firebase ID token
- `sourceLanguage` - required source language
- `sampleRate` - required positive integer
- `model` - optional STT model
- `language` - optional recognition language hint
- `diarize` - optional boolean
- `utterances` - optional boolean
- `punctuate` - optional boolean
- `smartFormat` - optional boolean
- `detectLanguage` - optional boolean

#### Server -> client `ready`

After the token is verified and the session starts, the server sends:

```json
{
  "type": "ready"
}
```

#### Client -> server audio

After `ready`, the client sends binary PCM chunks as WebSocket binary frames.

#### Server -> client recognition results

The server emits recognition messages like:

```json
{
  "type": "recognition_result",
  "isFinal": true,
  "speechFinal": true,
  "words": [
    {"word": "hello", "speaker": 0},
    {"word": "world", "speaker": 0}
  ]
}
```

#### Client -> server `stop`

When the client is done streaming audio, it sends:

```json
{
  "type": "stop"
}
```

The server closes the audio stream, allows recognition to finish, and then ends
the session.

#### Server -> client `error`

If session startup or streaming fails, the server sends:

```json
{
  "type": "error",
  "message": "Speech recognition stream failed."
}
```

## Error behavior

HTTP errors are returned as JSON:

```json
{
  "error": {
    "code": "bad_request",
    "message": "text is required"
  }
}
```

Common HTTP status codes:

- `400` malformed request body or missing required fields
- `401` missing/invalid bearer token
- `429` per-instance rate limit exceeded
- `503` downstream service unavailable
- `500` unexpected server error

## Headers and middleware behavior

- HTTP responses include `x-request-id`
- HTTP requests may be correlated with Cloud Trace via `x-cloud-trace-context`
- CORS is applied to HTTP routes based on `ALLOWED_ORIGINS`
- WebSocket upgrade traffic bypasses normal HTTP response mutation middleware

## Rate limiting

- HTTP routes are rate limited per instance by client IP
- `GET /v1/health` is exempt from HTTP rate limiting
- WebSocket STT sessions are rate limited separately per instance by client IP

## Source of truth in code

If the docs and code ever diverge, the current implementation lives in:

- `server/lib/src/http/api_router.dart`
- `server/lib/src/http/api_server.dart`
- `server/lib/src/http/live_stt_connection_handler.dart`
- `server/lib/src/models/translate_request.dart`
- `server/lib/src/models/tts_request.dart`
- `server/lib/src/models/live_stt_models.dart`
