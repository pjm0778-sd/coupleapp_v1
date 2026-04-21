#!/usr/bin/env bash
set -euo pipefail

FUNCTIONS=(
  "ocr-schedule"
  "schedule-table-ocr"
  "excel-schedule-parse"
  "odsay-proxy"
  "kakao-place-search"
  "naver-directions-proxy"
  "naver-place-search"
  "claude-midpoint"
  "claude-date-spots"
  "send-notification"
)

for fn in "${FUNCTIONS[@]}"; do
  echo "Deploying $fn with --no-verify-jwt ..."
  npx -y supabase functions deploy "$fn" --no-verify-jwt
  echo "Done: $fn"
  echo "-----------------------------"
done

echo "All functions deployed with JWT verification disabled."
