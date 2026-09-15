#!/usr/bin/env bash
# Trigger an OpenCode agent via opencode serve HTTP API (session + prompt_async).
set -euo pipefail

AGENT="${1:?usage: $0 <agent-name> [json-payload-file]}"
PAYLOAD_FILE="${2:-}"

BASE_URL="${OPENCODE_BASE_URL:?Set OPENCODE_BASE_URL, e.g. https://opencode.apps.cluster.example.com}"
USER="${OPENCODE_SERVER_USERNAME:-opencode}"
PASS="${OPENCODE_SERVER_PASSWORD:?Set OPENCODE_SERVER_PASSWORD}"

auth=(-u "${USER}:${PASS}")

SESSION_JSON="$(curl -sf "${auth[@]}" \
  -X POST "${BASE_URL}/session" \
  -H "Content-Type: application/json" \
  -d '{}')"

SESSION_ID="$(echo "${SESSION_JSON}" | jq -r '.id // .session.id // empty')"
if [[ -z "${SESSION_ID}" || "${SESSION_ID}" == "null" ]]; then
  echo "::error::Could not parse session id from: ${SESSION_JSON}"
  exit 1
fi

case "${AGENT}" in
  impact-analyzer)
    SKILL="dependency-impact-remediation"
    ;;
  mr-verifier)
    SKILL="mr-verify-ephemeral"
    ;;
  *)
    SKILL="${OPENCODE_SKILL_NAME:-}"
    ;;
esac

PROMPT_FILE="$(mktemp)"
if [[ -n "${PAYLOAD_FILE}" && -f "${PAYLOAD_FILE}" ]]; then
  INPUT_COMPACT="$(jq -c . "${PAYLOAD_FILE}")"
else
  INPUT_COMPACT="{}"
fi

jq -n \
  --arg agent "${AGENT}" \
  --arg skill "${SKILL}" \
  --argjson input "${INPUT_COMPACT}" \
  '{
    agent: $agent,
    parts: [{
      type: "text",
      text: ("Load skill " + $skill + " and execute it.\n\nInput JSON:\n" + ($input | tostring))
    }]
  }' > "${PROMPT_FILE}"

HTTP_CODE="$(curl -sf "${auth[@]}" -o /dev/null -w "%{http_code}" \
  -X POST "${BASE_URL}/session/${SESSION_ID}/prompt_async" \
  -H "Content-Type: application/json" \
  -d @"${PROMPT_FILE}")"

rm -f "${PROMPT_FILE}"

if [[ "${HTTP_CODE}" != "204" && "${HTTP_CODE}" != "200" ]]; then
  echo "::error::prompt_async returned HTTP ${HTTP_CODE}"
  exit 1
fi

echo "Triggered agent=${AGENT} session=${SESSION_ID} (HTTP ${HTTP_CODE})"
