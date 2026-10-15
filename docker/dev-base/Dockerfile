FROM mcr.microsoft.com/dotnet/sdk:10.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git gnupg jq ripgrep postgresql-client build-essential unzip \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE=1 \
    NUGET_CERT_REVOCATION_MODE=offline \
    MISE_DATA_DIR=/usr/local/share/mise \
    MISE_GLOBAL_CONFIG_FILE=/etc/mise/config.toml \
    MISE_CACHE_DIR=/tmp/mise-cache \
    MISE_YES=1 \
    PATH=/usr/local/mise-bin/node:/usr/local/mise-bin/bun:/usr/local/mise-bin/python:/usr/local/share/mise/shims:$PATH

COPY mise-link /usr/local/bin/mise-link
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise use --global node@24 bun@1 python@3.13 \
    && mise-link \
    && mise --version && node --version && bun --version && python --version && pip --version
