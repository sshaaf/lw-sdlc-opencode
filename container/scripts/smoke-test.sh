#!/usr/bin/env bash
# Smoke-test the OpenCode control-plane image (health API + baked config).
set -euo pipefail

IMAGE="${1:-sdlc-opencode:ci}"
PASSWORD="${SMOKE_TEST_PASSWORD:-smoke-test-secret}"
CONTAINER_NAME="opencode-smoke-${RANDOM}"
HEALTH_URL="http://127.0.0.1:4096/global/health"
MAX_WAIT_SECONDS="${SMOKE_TEST_TIMEOUT_SECONDS:-60}"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Verifying baked configuration in ${IMAGE}..."
docker run --rm --entrypoint sh "${IMAGE}" -c \
  'test -f /app/opencode.json && test -d /app/.opencode/skills && test -n "$(ls -A /app/.opencode/skills)" && command -v oc && command -v kubectl'

echo "Starting container ${CONTAINER_NAME}..."
docker run -d --name "${CONTAINER_NAME}" \
  -e "OPENCODE_SERVER_PASSWORD=${PASSWORD}" \
  -p 4096:4096 \
  "${IMAGE}" >/dev/null

echo "Waiting up to ${MAX_WAIT_SECONDS}s for ${HEALTH_URL}..."
deadline=$((SECONDS + MAX_WAIT_SECONDS))
healthy=0
while (( SECONDS < deadline )); do
  if response="$(curl -sf -u "opencode:${PASSWORD}" "${HEALTH_URL}" 2>/dev/null)"; then
    if echo "${response}" | grep -q '"healthy"[[:space:]]*:[[:space:]]*true'; then
      echo "Health check passed: ${response}"
      healthy=1
      break
    fi
  fi
  sleep 1
done

if (( healthy != 1 )); then
  echo "::error::Smoke test timed out after ${MAX_WAIT_SECONDS}s (expected healthy=true from /global/health)"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -50 || true
  exit 1
fi

echo "Smoke test succeeded."
