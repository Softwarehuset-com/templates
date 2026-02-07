# Templates

CI/CD workflow templates for Softwarehuset repos. Language-agnostic.

## Docker Build Template

**`workflows/build-images.yml`** - The main template for building Docker images.

### Format
```
dockerfile|image-name|context
```

### Single Image
```yaml
env:
  REGISTRY: code.core.ci/softwarehuset
  IMAGES: |
    ./Dockerfile|myapp|.
```

### Multi-Image
```yaml
env:
  REGISTRY: code.core.ci/softwarehuset
  IMAGES: |
    ./src/Dockerfile|api|./src
    ./frontend/Dockerfile|frontend|./frontend
    ./docs/Dockerfile|docs|./docs
```

### Tagging
| Event | Tag |
|-------|-----|
| PR | `pr-{number}` |
| Main push | `{sha}` + `latest` |

## Other Templates

| Template | Use Case |
|----------|----------|
| `forgejo-dotnet.yml` | .NET test job |
| `forgejo-node.yml` | Node.js test job |
| `forgejo-kustomize-deploy.yml` | Kubernetes deploy with kustomize |

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
SDK images lack Node.js for actions/checkout. Use git clone:
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
| `FORGEJO_TOKEN` | Git clone + Docker registry auth |
| `KUBE_CONFIG` | Base64 kubeconfig for deploys |

## AGENTS.md
Use `AGENTS-TEMPLATE.md` for repo-specific agent instructions.
