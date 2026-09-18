#!/usr/bin/env bash
# Optional laptop fallback — prefer bootstrap-tenant Job create-gitlab-tenant
# (gitlab.helpAppSeed.enabled) which clones the same GitHub repo in-cluster.
#
# Usage:
#   ./scripts/seed-help-app-to-gitlab.sh <guid>
#
# Env:
#   GITLAB_URL          default https://gitlab-gitlab.$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')
#   GITLAB_TOKEN        root or maintainer PAT (required)
#   GITLAB_GROUP         default lightwell
#   PROJECT_PATH        default lightwell/lw-demo-help-app-<guid>
#   HELP_APP_REPO       default https://github.com/sshaaf/lw-demo-help-app.git
#   HELP_APP_REF        default main
set -euo pipefail

GUID="${1:-}"
if [[ -z "${GUID}" ]]; then
  echo "Usage: $0 <guid>" >&2
  exit 1
fi

GROUP="${GITLAB_GROUP:-lightwell}"
PROJECT_PATH="${PROJECT_PATH:-${GROUP}/lw-demo-help-app-${GUID}}"
SEED_REPO="${HELP_APP_REPO:-https://github.com/sshaaf/lw-demo-help-app.git}"
SEED_REF="${HELP_APP_REF:-main}"

if [[ -z "${GITLAB_TOKEN:-}" ]]; then
  echo "ERROR: set GITLAB_TOKEN" >&2
  exit 1
fi

DOMAIN="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
GITLAB_URL="${GITLAB_URL:-https://gitlab-gitlab.${DOMAIN}}"
GITLAB_URL="${GITLAB_URL%/}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Seeding ${PROJECT_PATH} from ${SEED_REPO}@${SEED_REF} → ${GITLAB_URL}"
git -c http.sslVerify=false clone --depth 1 --branch "${SEED_REF}" "${SEED_REPO}" "${TMP}/src"
cd "${TMP}/src"
git remote remove origin 2>/dev/null || true
git checkout -B main
git config user.email "lightwell-seed@example.com"
git config user.name "lightwell-seed"

PUSH_URL="${GITLAB_URL}/${PROJECT_PATH}.git"
PUSH_URL_AUTH="$(echo "${PUSH_URL}" | sed "s#https://#https://oauth2:${GITLAB_TOKEN}@#")"
git remote add gitlab "${PUSH_URL_AUTH}"
git -c http.sslVerify=false push -u gitlab main --force

echo "Done. Clone: ${PUSH_URL}"
