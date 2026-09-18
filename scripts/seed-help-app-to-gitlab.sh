#!/usr/bin/env bash
# Seed tenant GitLab project with lw-demo-help-app sources (demo depth A).
#
# Usage:
#   ./scripts/seed-help-app-to-gitlab.sh <guid> [src-dir]
#
# Env:
#   GITLAB_URL          default https://gitlab-gitlab.$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')
#   GITLAB_TOKEN        root or maintainer PAT (required)
#   GITLAB_GROUP        default lightwell
#   PROJECT_PATH        default lightwell/lw-demo-help-app-<guid>
#
# Source defaults to sibling collateral app if present.
set -euo pipefail

GUID="${1:-}"
if [[ -z "${GUID}" ]]; then
  echo "Usage: $0 <guid> [src-dir]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_SRC="${ROOT}/../lightwell-demo-collateral/apps/lw-demo-help-app"
SRC="${2:-${HELP_APP_SRC:-$DEFAULT_SRC}}"
GROUP="${GITLAB_GROUP:-lightwell}"
PROJECT_PATH="${PROJECT_PATH:-${GROUP}/lw-demo-help-app-${GUID}}"

if [[ -z "${GITLAB_TOKEN:-}" ]]; then
  echo "ERROR: set GITLAB_TOKEN" >&2
  exit 1
fi

if [[ ! -d "${SRC}" ]]; then
  echo "ERROR: help-app source not found: ${SRC}" >&2
  exit 1
fi

DOMAIN="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
GITLAB_URL="${GITLAB_URL:-https://gitlab-gitlab.${DOMAIN}}"
GITLAB_URL="${GITLAB_URL%/}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Seeding ${PROJECT_PATH} from ${SRC} → ${GITLAB_URL}"
cp -a "${SRC}/." "${TMP}/"
# Drop nested .git if present so we push as a fresh tree
rm -rf "${TMP}/.git"
cd "${TMP}"
git init -q
git checkout -q -b main
git add -A
git -c user.email="lightwell-seed@example.com" -c user.name="lightwell-seed" commit -q -m "Seed lw-demo-help-app for tenant ${GUID}"

# Use oauth2 token form for HTTPS push
PUSH_URL="${GITLAB_URL}/${PROJECT_PATH}.git"
PUSH_URL_AUTH="$(echo "${PUSH_URL}" | sed "s#https://#https://oauth2:${GITLAB_TOKEN}@#")"
git remote add origin "${PUSH_URL_AUTH}"
git push -u origin main --force

echo "Done. Clone: ${PUSH_URL}"
