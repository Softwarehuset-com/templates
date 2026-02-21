# CI/CD Workflow Templates

Reusable Forgejo Actions workflow templates + a generator that composes them from minimal declarative config.

## Templates

| Template | Description |
|---|---|
| `workflows/test-dotnet.yml` | .NET test job (auto-detects docker-compose) |
| `workflows/test-node.yml` | Node.js test job (fnm + npm) |
| `workflows/test-python.yml` | Python test job (venv + pytest) |
| `workflows/build-images.yml` | Multi-image Docker builds |
| `workflows/deploy-kustomize.yml` | Kubernetes deploy via Kustomize |
| `workflows/deploy-helm.yml` | Kubernetes deploy via Helm |

## Generator

`generate.sh` reads a simple YAML config and outputs a complete `.forgejo/workflows/ci.yml`.

### Usage

```bash
# From your repo root:
/path/to/templates/generate.sh ci-config.yml > .forgejo/workflows/ci.yml
```

### Smart Defaults

The generator auto-detects as much as possible:

| Setting | Default | Auto-detection |
|---|---|---|
| `solution-path` | — | Scans repo for `*.slnx` / `*.sln` (excludes vendor/) |
| `docker-compose` | `false` | Set to `auto` to detect `docker-compose.yml` presence |
| `submodules` | `true` | — |
| `dotnet-channel` | `10` | — |
| `node-version` | `22` | — |
| `registry` | `code.core.ci/softwarehuset` | — |
| `timeout-minutes` | `20` | — |

### Config Format

Everything is declarative blocks. No custom shell commands.

```yaml
# Minimal .NET + Docker + Deploy config:
test-dotnet:
  docker-compose: auto       # auto-detect docker-compose.yml

build-images:
  - ./Dockerfile|myapp|.     # format: dockerfile|image-name|context

deploy-kustomize:
  namespace: myapp
  deployment: myapp
  image: myapp
```

### Supported Blocks

#### `test-dotnet`

```yaml
test-dotnet:
  name: test-backend          # job name (default: test-backend)
  solution-path: src/App.sln  # auto-detected if omitted
  docker-compose: auto        # auto | true | false
  dotnet-channel: "10"        # default: 10
  submodules: true            # default: true
  timeout-minutes: 20         # default: 20
```

#### `test-node`

```yaml
test-node:
  name: test-frontend         # job name (default: test-frontend)
  working-directory: frontend  # optional
  node-version: "22"          # default: 22
  timeout-minutes: 20
```

#### `test-python`

```yaml
test-python:
  name: test                  # job name (default: test)
  docker-compose: auto
  timeout-minutes: 20
```

#### `build-images`

List of `dockerfile|image-name|context`:

```yaml
build-images:
  - ./backend/Dockerfile|api|.
  - ./frontend/Dockerfile|frontend|./frontend
```

#### `deploy-kustomize`

```yaml
deploy-kustomize:
  namespace: myapp
  kustomize-path: k8s/prod    # default: k8s/prod

  # Single deployment:
  deployment: myapp
  image: myapp

  # Or multiple deployments:
  deployments:
    - deployment: api
      image: api
      container: api
    - deployment: frontend
      image: frontend
      container: frontend
```

#### `deploy-helm`

```yaml
deploy-helm:
  namespace: myapp
  release: myapp              # default: namespace
  chart: oci://registry/charts/myapp
  chart-version: "1.0.0"     # optional
  values-file: values.yaml   # default: values.yaml
```

### Global Settings

Set at the top level to override defaults:

```yaml
registry: my-registry.example.com/org
timeout-minutes: 30
submodules: false
dotnet-channel: "9.0"

test-dotnet: {}
build-images:
  - ./Dockerfile|app|.
```

### Example: Full Stack App

```yaml
test-dotnet:
  docker-compose: auto

test-node:
  working-directory: frontend

build-images:
  - ./backend/Dockerfile|api|.
  - ./frontend/Dockerfile|frontend|./frontend

deploy-kustomize:
  namespace: myapp
  kustomize-path: k8s/prod
  deployments:
    - deployment: api
      image: api
      container: api
    - deployment: frontend
      image: frontend
      container: frontend
```

### Job Dependencies

The generator automatically wires `needs:` between jobs:
- **build-images** needs all test jobs
- **deploy** needs build-images (or test jobs if no build)
