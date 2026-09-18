# OpenCode control-plane image for OpenShift (skills and config baked at build time).
#
# Build context MUST be the repository root (not container/), e.g.:
#   docker build -f container/Dockerfile -t sdlc-opencode:ci .
#   ./container/build.sh
FROM ghcr.io/anomalyco/opencode:latest

USER root
RUN apk add --no-cache git openssh-client ca-certificates python3 \
  && mkdir -p /app \
  && chown -R 1001:0 /app \
  && chmod -R g+rwX /app

WORKDIR /app

COPY --chown=1001:0 opencode.json /app/opencode.json
COPY --chown=1001:0 .opencode /app/.opencode
COPY --chown=1001:0 scripts /app/scripts

EXPOSE 4096

ENV OPENCODE_HOSTNAME=0.0.0.0
ENV OPENCODE_PORT=4096
ENV HOME=/tmp
ENV XDG_DATA_HOME=/tmp

# Secrets (LLM keys, GITLAB_USERNAME/PASSWORD, derived GITLAB_PAT, OPENCODE_SERVER_PASSWORD) at runtime.
USER 1001
ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
