# Templates

CI/CD workflow templates for Softwarehuset repos.

## Core Templates

### `build-images.yml` - Docker Build

**The only way to build Docker images.**

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

### Test Templates

All test templates **auto-detect docker-compose.yml** and spin up services if present.

| Template | Language |
|----------|----------|
| `test-dotnet.yml` | .NET 9.0 |
| `test-node.yml` | Node.js 22 |
| `test-python.yml` | Python 3 |

### `deploy-kustomize.yml` - Kubernetes Deploy

## Auto Docker-Compose

If your repo has a `docker-compose.yml`, the test templates will:
1. `docker-compose up -d` before tests
2. Run your tests
3. `docker-compose down` after (always, even on failure)

No config needed. Just have a docker-compose.yml.

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
  test:
    name: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start services
        run: |
          if [ -f docker-compose.yml ]; then
            docker-compose up -d && sleep 5
          fi
      - run: npm ci
      - run: npm test
      - name: Stop services
        if: always()
        run: docker-compose down 2>/dev/null || true

  docker:
    name: docker
    runs-on: ubuntu-latest
    steps:
      # ... from build-images.yml

  deploy:
    name: deploy
    needs: [test, docker]
    if: github.ref == 'refs/heads/main'
    # ... from deploy-kustomize.yml
```

## Required Org Secrets

| Secret | Purpose |
|--------|---------|
| `FORGEJO_TOKEN` | Git clone + Docker registry |
| `KUBE_CONFIG` | Base64 kubeconfig for deploys |
