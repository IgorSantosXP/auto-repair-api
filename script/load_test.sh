#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?informe a URL base, ex.: https://abc123.execute-api.us-east-1.amazonaws.com}"
DURATION="${2:-300}"
CONCURRENCY="${3:-30}"

echo "Target:      $BASE_URL"
echo "Duration:    ${DURATION}s"
echo "Concurrency: $CONCURRENCY workers"
echo

TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@autorepair.com","password":"admin123456"}' \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Login failed — is the API up and seeded?"
  exit 1
fi

echo "Authenticated. Starting load..."
echo "Watch the autoscaler in another terminal:"
echo "  kubectl -n auto-repair-prod get hpa,pods -w"
echo

END=$(( $(date +%s) + DURATION ))

worker() {
  local count=0
  while [ "$(date +%s)" -lt "$END" ]; do
    curl -s -o /dev/null "$BASE_URL/api/v1/service_orders" \
      -H "Authorization: Bearer $TOKEN"
    count=$((count + 1))
  done
  echo "$count" >> "$TMP_COUNTS"
}

TMP_COUNTS=$(mktemp)
trap 'rm -f "$TMP_COUNTS"' EXIT

for _ in $(seq "$CONCURRENCY"); do
  worker &
done
wait

TOTAL=$(awk '{s+=$1} END {print s}' "$TMP_COUNTS")
echo "Done. Total requests: ${TOTAL:-0} in ${DURATION}s (~$(( ${TOTAL:-0} / DURATION )) req/s)"
