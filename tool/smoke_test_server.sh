#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${API_BASE_URL:-http://localhost:8080}"
FIREBASE_ID_TOKEN="${FIREBASE_ID_TOKEN:-}"
EXPECT_AUTH_SUCCESS="${EXPECT_AUTH_SUCCESS:-auto}"

usage() {
  cat <<'EOF'
Usage:
  API_BASE_URL=http://localhost:8080 tool/smoke_test_server.sh
  API_BASE_URL=https://your-service.run.app FIREBASE_ID_TOKEN=token tool/smoke_test_server.sh

Environment:
  API_BASE_URL         Base URL to test. Defaults to http://localhost:8080
  FIREBASE_ID_TOKEN    Optional Firebase bearer token for authenticated checks
  EXPECT_AUTH_SUCCESS  auto|true|false. Defaults to auto.

Behavior:
  - Always checks GET /v1/health
  - If FIREBASE_ID_TOKEN is set, checks GET /v1/capabilities with auth
  - If FIREBASE_ID_TOKEN is not set and EXPECT_AUTH_SUCCESS=false, verifies
    that GET /v1/capabilities returns 401
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_command curl
require_command python3

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

health_body="$tmp_dir/health.json"
cap_body="$tmp_dir/capabilities.json"

printf 'Smoke testing %s\n' "$BASE_URL"

health_status="$(
  curl -sS -o "$health_body" -w '%{http_code}' "$BASE_URL/v1/health"
)"

if [[ "$health_status" != "200" ]]; then
  printf 'Health check failed with status %s\n' "$health_status" >&2
  cat "$health_body" >&2
  exit 1
fi

python3 - "$health_body" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    payload = json.load(f)

if payload.get('status') != 'ok':
    raise SystemExit(f"Unexpected health payload: {payload}")
PY

printf 'Health check passed\n'

if [[ -n "$FIREBASE_ID_TOKEN" ]]; then
  cap_status="$(
    curl -sS -o "$cap_body" -w '%{http_code}' \
      -H "Authorization: Bearer $FIREBASE_ID_TOKEN" \
      "$BASE_URL/v1/capabilities"
  )"

  if [[ "$cap_status" != "200" ]]; then
    printf 'Authenticated capabilities check failed with status %s\n' "$cap_status" >&2
    cat "$cap_body" >&2
    exit 1
  fi

  python3 - "$cap_body" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    payload = json.load(f)

required = {
    'status': 'ok',
    'translationProviders': list,
    'ttsProviders': list,
    'sttProviders': list,
}

for key, expected in required.items():
    if key not in payload:
        raise SystemExit(f"Missing key in capabilities payload: {key}")
    if expected is list and not isinstance(payload[key], list):
        raise SystemExit(f"Expected list for {key}: {payload}")
    if expected is not list and payload[key] != expected:
        raise SystemExit(f"Unexpected value for {key}: {payload}")
PY

  printf 'Authenticated capabilities check passed\n'
  exit 0
fi

if [[ "$EXPECT_AUTH_SUCCESS" == "true" ]]; then
  printf 'FIREBASE_ID_TOKEN is required when EXPECT_AUTH_SUCCESS=true\n' >&2
  exit 1
fi

if [[ "$EXPECT_AUTH_SUCCESS" == "false" ]]; then
  cap_status="$(
    curl -sS -o "$cap_body" -w '%{http_code}' "$BASE_URL/v1/capabilities"
  )"

  if [[ "$cap_status" != "401" ]]; then
    printf 'Expected unauthenticated capabilities check to return 401, got %s\n' "$cap_status" >&2
    cat "$cap_body" >&2
    exit 1
  fi

  printf 'Unauthenticated capabilities check returned 401 as expected\n'
else
  printf 'Skipping authenticated capabilities check; set FIREBASE_ID_TOKEN to enable it\n'
fi
