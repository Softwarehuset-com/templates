ARG BASE
ARG RUNTIME=ghcr.io/paperclipai/agent-runtime-claude:git-38d8f371722b315d2fb3bbaa512518742e33ce2f

FROM ${RUNTIME} AS runtime

FROM ${BASE}
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git tini ripgrep \
    && if ! command -v node >/dev/null; then curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && apt-get install -y --no-install-recommends nodejs; fi \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code@latest opencode-ai@latest \
    && ln -sf "$(command -v claude)" /usr/bin/claude-code \
    && if ! getent passwd 1000 >/dev/null; then groupadd -g 1000 paperclip && useradd -u 1000 -g 1000 -m -s /bin/bash paperclip; fi \
    && mkdir -p /workspace && chown 1000:1000 /workspace
COPY --from=runtime /usr/local/bin/paperclip-agent-shim /usr/local/bin/paperclip-agent-shim
USER 1000:1000
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/paperclip-agent-shim"]
