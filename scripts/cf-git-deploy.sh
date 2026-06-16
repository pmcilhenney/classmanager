#!/usr/bin/env bash
set -euo pipefail

echo "Cloudflare build diagnostics"
echo "pwd: $(pwd)"
echo "node: $(node --version)"
echo "npm: $(npm --version)"
echo "git commit: $(git rev-parse HEAD 2>/dev/null || echo unavailable)"
echo "git branch: $(git branch --show-current 2>/dev/null || echo unavailable)"
echo "repo root files:"
find . -maxdepth 1 -type f -print | sort

if [[ ! -f wrangler.json ]]; then
  echo "wrangler.json is missing from the Cloudflare checkout." >&2
  echo "This checkout is not the current repo root from GitHub main." >&2
  exit 66
fi

if [[ ! -f worker/src/index.ts ]]; then
  echo "worker/src/index.ts is missing from the Cloudflare checkout." >&2
  exit 67
fi

npx wrangler deploy --config ./wrangler.json "$@"
