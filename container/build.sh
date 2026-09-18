#!/usr/bin/env bash
# Build from repo root so COPY opencode.json and .opencode/ resolve correctly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-sdlc-opencode:ci}"
PLATFORM="${PLATFORM:-linux/amd64}"

if command -v podman >/dev/null 2>&1; then
  exec podman build --platform="${PLATFORM}" -f "${ROOT}/container/Dockerfile" -t "${TAG}" "${ROOT}"
fi
exec docker build --platform="${PLATFORM}" -f "${ROOT}/container/Dockerfile" -t "${TAG}" "${ROOT}"
