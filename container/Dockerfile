# OpenCode control-plane image for OpenShift (skills and config baked at build time).
#
# Build context MUST be the repository root (not container/), e.g.:
#   docker build -f container/Dockerfile -t sdlc-opencode:ci .
#   ./container/build.sh
#
# OpenShift runs as an arbitrary UID in group 0. Writable paths are owned
# 1001:0 with g+rwX so any UID in the root group can create logs/cache.
FROM ghcr.io/anomalyco/opencode:latest

USER root
RUN apk add --no-cache git openssh-client ca-certificates python3 \
  && mkdir -p /app /tmp/opencode/log \
  && chown -R 1001:0 /app /tmp/opencode \
  && chmod -R g+rwX /app /tmp/opencode \
  && chmod 1777 /tmp

WORKDIR /app

COPY --chown=1001:0 opencode.json /app/opencode.json
COPY --chown=1001:0 .opencode /app/.opencode
COPY --chown=1001:0 scripts /app/scripts

EXPOSE 4096

ENV OPENCODE_HOSTNAME=0.0.0.0
ENV OPENCODE_PORT=4096
# Ephemeral runtime state; works with an emptyDir on /tmp in OpenShift.
ENV HOME=/tmp
ENV XDG_DATA_HOME=/tmp
ENV XDG_CACHE_HOME=/tmp
ENV XDG_CONFIG_HOME=/tmp

# Secrets (LLM keys, GITLAB_USERNAME/PASSWORD, derived GITLAB_PAT, OPENCODE_SERVER_PASSWORD) at runtime.
USER 1001
# --print-logs: agent/session activity to container stderr (oc logs). File log still at $XDG_DATA_HOME/opencode/log/.
ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096", "--print-logs", "--log-level", "INFO"]
