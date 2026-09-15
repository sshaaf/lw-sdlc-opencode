#!/usr/bin/env bash
# Build from repo root so COPY opencode.json and .opencode/ resolve correctly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-sdlc-opencode:ci}"

exec docker build -f "${ROOT}/container/Dockerfile" -t "${TAG}" "${ROOT}"
