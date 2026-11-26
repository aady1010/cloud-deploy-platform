#!/usr/bin/env bash
# Usage: smoke_test.sh <base_url> <expected_version>
# Verifies the NEW version is live (catches silent rollbacks) and basic endpoints work.
set -euo pipefail
URL="${1:?base url}"; EXPECTED="${2:?expected version}"

echo "Waiting for $URL to serve version $EXPECTED ..."
for i in $(seq 1 30); do
  live=$(curl -fsS --max-time 5 "$URL/version" 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["version"])' 2>/dev/null || true)
  if [ "$live" = "$EXPECTED" ]; then echo "Version OK ($live)"; break; fi
  echo "  attempt $i: live version='${live:-none}'"; sleep 10
  if [ "$i" = 30 ]; then echo "Expected version never became live (possible rollback)"; exit 1; fi
done

curl -fsS "$URL/health" >/dev/null && echo "health OK"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/api/items" -H 'content-type: application/json' -d '{"name":"smoke"}')
[ "$code" = 201 ] && echo "POST /api/items OK" || { echo "POST failed: $code"; exit 1; }
echo "Smoke test passed"
