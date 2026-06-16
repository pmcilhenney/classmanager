#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORKER_NAME="${WORKER_NAME:-classmanager-api}"
D1_NAME="${D1_NAME:-classmanager-db}"
D1_LOCATION="${D1_LOCATION:-enam}"
R2_BUCKET="${R2_BUCKET:-classmanager-artifacts}"
CONFIG_PATH="${CONFIG_PATH:-wrangler.generated.jsonc}"
TEMPLATE_PATH="${TEMPLATE_PATH:-wrangler.template.jsonc}"

deploy=false
if [[ "${1:-}" == "--deploy" ]]; then
  deploy=true
fi

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command wrangler
need_command jq

echo "Checking Cloudflare account..."
wrangler whoami >/dev/null

echo "Ensuring D1 database: $D1_NAME"
d1_json="$(wrangler d1 list --json)"
d1_id="$(printf '%s' "$d1_json" | jq -r --arg name "$D1_NAME" '
  map(select((.name // .database_name // "") == $name))[0]
  | (.uuid // .id // .database_id // "")
')"

if [[ -z "$d1_id" || "$d1_id" == "null" ]]; then
  wrangler d1 create "$D1_NAME" --location "$D1_LOCATION"
  d1_json="$(wrangler d1 list --json)"
  d1_id="$(printf '%s' "$d1_json" | jq -r --arg name "$D1_NAME" '
    map(select((.name // .database_name // "") == $name))[0]
    | (.uuid // .id // .database_id // "")
  ')"
fi

if [[ -z "$d1_id" || "$d1_id" == "null" ]]; then
  echo "Could not resolve D1 database id for $D1_NAME." >&2
  exit 1
fi

echo "Ensuring R2 bucket: $R2_BUCKET"
if ! wrangler r2 bucket list | awk '{print $1}' | grep -Fxq "$R2_BUCKET"; then
  wrangler r2 bucket create "$R2_BUCKET" --location "$D1_LOCATION"
fi

echo "Writing generated Wrangler config: $CONFIG_PATH"
sed \
  -e "s/__D1_DATABASE_NAME__/$D1_NAME/g" \
  -e "s/__D1_DATABASE_ID__/$d1_id/g" \
  -e "s/__R2_BUCKET_NAME__/$R2_BUCKET/g" \
  "$TEMPLATE_PATH" > "$CONFIG_PATH"

echo "Applying remote D1 migrations..."
wrangler d1 migrations apply DB -c "$CONFIG_PATH" --remote

if [[ "$deploy" == true ]]; then
  echo "Deploying Worker: $WORKER_NAME"
  wrangler deploy -c "$CONFIG_PATH" --keep-vars
else
  echo "Bootstrap complete. Run 'npm run cf:deploy' to deploy after secrets are set."
fi
