# Templates

CI/CD workflow templates for Softwarehuset repos.

## Core Templates

### `build-images.yml` - Docker Build (THE way to build images)

```yaml
env:
  REGISTRY: code.core.ci/softwarehuset
  IMAGES: |
    ./Dockerfile|myapp|.
    ./frontend/Dockerfile|myapp-frontend|./frontend
```

Format: `dockerfile|image-name|context` (one per line)

| Event | Tag |
|-------|-----|
| PR | `pr-{number}` |
| Main | `{sha}` + `latest` |

### `test-dotnet.yml` - .NET Test

### `test-node.yml` - Node.js Test

### `deploy-kustomize.yml` - Kubernetes Deploy

## Full Example

```yaml
name: myapp

on:
  push:
    branches: [main]
  pull_request:

env:
  REGISTRY: code.core.ci/softwarehuset
  IMAGES: |
    ./Dockerfile|myapp|.

jobs:
  # From test-dotnet.yml or test-node.yml
  test:
    name: test
    # ...

  # From build-images.yml
  docker:
    name: docker
    # ...

  # From deploy-kustomize.yml
  deploy:
    name: deploy
    needs: [test, docker]
    if: github.ref == 'refs/heads/main'
    # ...
```

## Conventions

### Job Naming
```yaml
jobs:
  test:
    name: test
  docker:
    name: docker
  deploy:
    name: deploy
```

### Container Job Checkout
SDK images lack Node.js. Use git clone:
```yaml
- name: Checkout
  env:
    TOKEN: ${{ secrets.FORGEJO_TOKEN }}
  run: |
    git config --global --add safe.directory "$GITHUB_WORKSPACE"
    git clone --depth=1 "https://djohn:${TOKEN}@code.core.ci/${{ github.repository }}.git" .
    git fetch origin "${{ github.ref }}" --depth=1
    git checkout FETCH_HEAD
```

### Required Org Secrets
| Secret | Purpose |
|--------|---------|
| `FORGEJO_TOKEN` | Git clone + Docker registry |
| `KUBE_CONFIG` | Base64 kubeconfig for deploys |
