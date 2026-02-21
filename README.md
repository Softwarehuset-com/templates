# Templates

Reusable CI/CD workflows for Forgejo. Other repos call these via `uses:` — no generator scripts, no copy-paste.

## Available Workflows

| Workflow | Description |
|---|---|
| `test-dotnet.yml` | .NET restore → build → test with auto-detection |
| `test-node.yml` | Node.js install → npm/yarn/pnpm test |
| `test-python.yml` | Python pip install → pytest |
| `build-images.yml` | Build and push Docker images |
| `deploy-kustomize.yml` | Deploy via kubectl + kustomize |
| `deploy-helm.yml` | Deploy via Helm upgrade --install |

## Usage

Add a workflow file to your repo (e.g. `.forgejo/workflows/ci.yml`):

### .NET

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    uses: softwarehuset/templates/.forgejo/workflows/test-dotnet.yml@main
    # That's it! Defaults handle the rest:
    # - auto-detects *.sln / *.slnx
    # - auto-detects and starts docker-compose if present
    # - .NET 9.0, submodules enabled
    # - test filter: Category!=Live&Category!=Integration

  # Or with overrides:
  test-custom:
    uses: softwarehuset/templates/.forgejo/workflows/test-dotnet.yml@main
    with:
      dotnet-channel: "10.0"
      solution-path: "src/MyApp.sln"
      test-filter: ""
```

### Node.js

```yaml
jobs:
  test:
    uses: softwarehuset/templates/.forgejo/workflows/test-node.yml@main
    # auto-detects package.json, lockfile → npm/yarn/pnpm
    
  test-custom:
    uses: softwarehuset/templates/.forgejo/workflows/test-node.yml@main
    with:
      node-version: "20"
      working-directory: "frontend"
```

### Python

```yaml
jobs:
  test:
    uses: softwarehuset/templates/.forgejo/workflows/test-python.yml@main
    # auto-detects pyproject.toml or setup.py
```

### Build Images

```yaml
jobs:
  build:
    uses: softwarehuset/templates/.forgejo/workflows/build-images.yml@main
    with:
      images: |
        Dockerfile|my-api|.
        src/worker/Dockerfile|my-worker|src/worker
```

### Deploy (Kustomize)

```yaml
jobs:
  deploy:
    needs: [build]
    uses: softwarehuset/templates/.forgejo/workflows/deploy-kustomize.yml@main
    with:
      namespace: production
      deployment: my-api
      image: my-api
```

### Deploy (Helm)

```yaml
jobs:
  deploy:
    uses: softwarehuset/templates/.forgejo/workflows/deploy-helm.yml@main
    with:
      helm_repo: https://charts.example.com
      helm_repo_name: myrepo
      chart: my-chart
      release: my-release
      namespace: production
      version: "1.2.3"
      values_file: k8s/values.yaml
```

## Runner Requirements

These workflows are designed for **bare-metal Ubuntu runners**:

- No `container:` or `services:` (not supported)
- Uses `wget` (not `curl`) for downloads
- .NET installed via `dotnet-install.sh` (not `actions/setup-dotnet`)
- Docker compose v2 (`docker compose`, not `docker-compose`)
- Secrets are inherited automatically (Forgejo doesn't support `secrets:` in `workflow_call`)

## Smart Defaults

All workflows use smart auto-detection:

- **Solution path**: Finds `*.sln` / `*.slnx` recursively (up to 3 levels)
- **Docker compose**: Finds and starts `docker-compose.yml` / `compose.yml` if present
- **Package manager**: Detects `pnpm-lock.yaml` / `yarn.lock` / `package-lock.json`
- **Python project**: Detects `pyproject.toml` / `setup.py` / `requirements.txt`

## Samples

The `samples/dotnet-api/` directory contains a sample .NET API with tests and docker-compose, used to validate the `test-dotnet.yml` workflow in this repo's own CI.
