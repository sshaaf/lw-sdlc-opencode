# OpenCode control-plane image for OpenShift (skills and config baked at build time).
#
# Build context MUST be the repository root (not container/), e.g.:
#   docker build -f container/Dockerfile -t sdlc-opencode:ci .
#   ./container/build.sh
FROM ghcr.io/anomalyco/opencode:latest

USER root
RUN apk add --no-cache git openssh-client ca-certificates

WORKDIR /app

COPY opencode.json /app/opencode.json
COPY .opencode /app/.opencode

EXPOSE 4096

ENV OPENCODE_HOSTNAME=0.0.0.0
ENV OPENCODE_PORT=4096

# Secrets (LLM keys, GITLAB_PAT, OPENCODE_SERVER_PASSWORD) are injected at runtime on OpenShift.
ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
