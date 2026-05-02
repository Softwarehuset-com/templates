# Templates

Reusable CI/CD workflows for Forgejo. Other repos call these via `uses:` — no generator scripts, no copy-paste.

## Available Workflows

| Workflow | Description |
|---|---|
| `test-dotnet.yml` | .NET restore → build → test with auto-detection |
| `test-node.yml` | Node.js install → npm/yarn/pnpm test |
| `test-python.yml` | Python pip install → pytest |
| `test-e2e-dotnet-playwright.yml` | .NET + Playwright E2E (browser install + retry on flake) |
| `build-images.yml` | Build and push Docker images |
| `scan-images.yml` | Build Docker images and run a Trivy vulnerability scan (CRITICAL by default) |
| `secret-scan.yml` | Scan repository contents for committed secrets via gitleaks |
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

### Secret Scan (gitleaks)

```yaml
jobs:
  secret-scan:
    runs-on: ubuntu-latest
    uses: softwarehuset/templates/.forgejo/workflows/secret-scan.yml@main
    # Defaults: gitleaks v8.21.2, .gitleaks.toml if present, scans the whole tree.
```

### Image Scan (Trivy)

```yaml
jobs:
  image-scan:
    needs: [docker]
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    uses: softwarehuset/templates/.forgejo/workflows/scan-images.yml@main
    with:
      images: |
        ./backend/Dockerfile|my-api|.
        ./frontend/Dockerfile|my-frontend|./frontend
      severity: "CRITICAL"     # default
      upload-sarif: true       # default false
```

### E2E (.NET + Playwright)

```yaml
jobs:
  test-e2e:
    needs: [docker]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    uses: softwarehuset/templates/.forgejo/workflows/test-e2e-dotnet-playwright.yml@main
    with:
      project-path: backend/MyApp.E2E.Tests/MyApp.E2E.Tests.csproj
      backend-url: https://my-app.example.com
      frontend-url: https://my-app.example.com
      # retries: 1   (default — one retry, two attempts total)
      # browser: chromium  (default; or firefox/webkit/all)
    secrets: inherit
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
