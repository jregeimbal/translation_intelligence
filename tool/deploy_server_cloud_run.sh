#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  GCP_PROJECT_ID=my-project \
  ARTIFACT_REPOSITORY=translation-intelligence \
  ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com \
  FIREBASE_PROJECT_ID=my-firebase-project \
  tool/deploy_server_cloud_run.sh

Required environment variables:
  ALLOWED_ORIGINS
  FIREBASE_PROJECT_ID

Optional environment variables:
  GCP_PROJECT_ID                 Defaults to current gcloud project
  CLOUD_RUN_SERVICE              Defaults to translation-intelligence-server
  CLOUD_RUN_REGION               Defaults to us-central1
  ARTIFACT_REPOSITORY            Defaults to translation-intelligence
  IMAGE_NAME                     Defaults to translation-intelligence-server
  IMAGE_TAG                      Defaults to latest
  HTTP_RATE_LIMIT_PER_MINUTE     Defaults to 120
  WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE Defaults to 30
  FIREBASE_WEB_API_KEY_SECRET    Defaults to FIREBASE_WEB_API_KEY
  DEEPGRAM_API_KEY_SECRET        Defaults to DEEPGRAM_API_KEY
  GOOGLE_SERVICE_ACCOUNT_JSON_SECRET Defaults to GOOGLE_SERVICE_ACCOUNT_JSON
  CLOUD_RUN_ALLOW_UNAUTHENTICATED Defaults to true

This script:
  1. Builds and pushes the server image with Cloud Build
  2. Deploys that image to Cloud Run
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

require_command gcloud

GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
CLOUD_RUN_SERVICE="${CLOUD_RUN_SERVICE:-translation-intelligence-server}"
CLOUD_RUN_REGION="${CLOUD_RUN_REGION:-us-central1}"
ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-translation-intelligence}"
IMAGE_NAME="${IMAGE_NAME:-translation-intelligence-server}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
HTTP_RATE_LIMIT_PER_MINUTE="${HTTP_RATE_LIMIT_PER_MINUTE:-120}"
WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE="${WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE:-30}"
FIREBASE_WEB_API_KEY_SECRET="${FIREBASE_WEB_API_KEY_SECRET:-FIREBASE_WEB_API_KEY}"
DEEPGRAM_API_KEY_SECRET="${DEEPGRAM_API_KEY_SECRET:-DEEPGRAM_API_KEY}"
GOOGLE_SERVICE_ACCOUNT_JSON_SECRET="${GOOGLE_SERVICE_ACCOUNT_JSON_SECRET:-GOOGLE_SERVICE_ACCOUNT_JSON}"
CLOUD_RUN_ALLOW_UNAUTHENTICATED="${CLOUD_RUN_ALLOW_UNAUTHENTICATED:-true}"

require_env GCP_PROJECT_ID
require_env ALLOWED_ORIGINS
require_env FIREBASE_PROJECT_ID

IMAGE_URI="${CLOUD_RUN_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"
ENV_VARS="^@^ALLOWED_ORIGINS=${ALLOWED_ORIGINS}@HTTP_RATE_LIMIT_PER_MINUTE=${HTTP_RATE_LIMIT_PER_MINUTE}@WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE=${WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE}@FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}"
SECRET_VARS="FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY_SECRET}:latest,DEEPGRAM_API_KEY=${DEEPGRAM_API_KEY_SECRET}:latest,GOOGLE_SERVICE_ACCOUNT_JSON=${GOOGLE_SERVICE_ACCOUNT_JSON_SECRET}:latest"

printf 'Building image %s\n' "$IMAGE_URI"
gcloud builds submit ./server \
  --project "$GCP_PROJECT_ID" \
  --config server/cloudbuild.yaml \
  --substitutions "_REGION=${CLOUD_RUN_REGION},_REPOSITORY=${ARTIFACT_REPOSITORY},_IMAGE_NAME=${IMAGE_NAME},_TAG=${IMAGE_TAG}"

deploy_args=(
  run deploy "$CLOUD_RUN_SERVICE"
  --project "$GCP_PROJECT_ID"
  --image "$IMAGE_URI"
  --region "$CLOUD_RUN_REGION"
  --platform managed
  --port 8080
  --set-env-vars "$ENV_VARS"
  --set-secrets "$SECRET_VARS"
)

if [[ "$CLOUD_RUN_ALLOW_UNAUTHENTICATED" == "true" ]]; then
  deploy_args+=(--allow-unauthenticated)
else
  deploy_args+=(--no-allow-unauthenticated)
fi

printf 'Deploying service %s\n' "$CLOUD_RUN_SERVICE"
gcloud "${deploy_args[@]}"

printf 'Deployed %s\n' "$IMAGE_URI"
