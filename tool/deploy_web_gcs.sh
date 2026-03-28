#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  WEB_BUCKET=my-web-bucket \
  API_BASE_URL=https://your-api.example.com \
  tool/deploy_web_gcs.sh

Required environment variables:
  WEB_BUCKET       GCS bucket name without gs://
  API_BASE_URL     Backend base URL compiled into the Flutter web build

Optional environment variables:
  WEB_BUCKET_PATH  Object prefix inside the bucket, default empty
  BUILD_DIR        Local Flutter web output directory, default build/web
  WEB_URL          Public URL to print instead of the storage.googleapis.com URL

This script:
  1. Builds a Flutter web release bundle
  2. Syncs the bundle to Google Cloud Storage
  3. Applies no-cache headers to entry files that should refresh on deploy
  4. Prints the deployed URL
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

require_env() {
  local key="$1"
  if [[ -z "${!key:-}" ]]; then
    printf 'Missing required environment variable: %s\n' "$key" >&2
    exit 1
  fi
}

trim_slashes() {
  local value="$1"
  value="${value#/}"
  value="${value%/}"
  printf '%s' "$value"
}

require_command flutter
require_command gcloud

WEB_BUCKET="$(trim_slashes "${WEB_BUCKET:-}")"
WEB_BUCKET_PATH="$(trim_slashes "${WEB_BUCKET_PATH:-}")"
BUILD_DIR="${BUILD_DIR:-build/web}"
WEB_URL="${WEB_URL:-}"

require_env WEB_BUCKET
require_env API_BASE_URL

bucket_uri="gs://${WEB_BUCKET}"
destination_uri="$bucket_uri"

if [[ -n "$WEB_BUCKET_PATH" ]]; then
  destination_uri+="/${WEB_BUCKET_PATH}"
fi

printf 'Building Flutter web release for %s\n' "$API_BASE_URL"
flutter build web \
  --release \
  --dart-define="NO_DOTENV_OVERRIDE=true" \
  --dart-define="API_BASE_URL=${API_BASE_URL}"

if [[ ! -d "$BUILD_DIR" ]]; then
  printf 'Build output not found: %s\n' "$BUILD_DIR" >&2
  exit 1
fi

printf 'Syncing %s to %s\n' "$BUILD_DIR" "$destination_uri"
gcloud storage rsync \
  --recursive \
  --delete-unmatched-destination-objects \
  "$BUILD_DIR" \
  "$destination_uri"

set_no_cache() {
  local file_name="$1"
  local object_uri="$destination_uri/$file_name"

  if [[ -f "$BUILD_DIR/$file_name" ]]; then
    gcloud storage objects update \
      "$object_uri" \
      --cache-control="no-store, max-age=0"
  fi
}

set_no_cache index.html
set_no_cache flutter_bootstrap.js
set_no_cache flutter_service_worker.js
set_no_cache manifest.json
set_no_cache version.json

default_url="https://storage.googleapis.com/${WEB_BUCKET}"
if [[ -n "$WEB_BUCKET_PATH" ]]; then
  default_url+="/${WEB_BUCKET_PATH}"
fi
default_url+="/index.html"

deployed_url="$default_url"
if [[ -n "$WEB_URL" ]]; then
  deployed_url="${WEB_URL%/}"
  if [[ -n "$WEB_BUCKET_PATH" ]]; then
    deployed_url+="/${WEB_BUCKET_PATH}"
  fi
  if [[ "$deployed_url" != *.html ]]; then
    deployed_url+="/"
  fi
fi

printf 'Deployment URL: %s\n' "$deployed_url"