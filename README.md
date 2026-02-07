# Templates

CI/CD workflow templates and conventions for Softwarehuset repos.

## Workflows

| Template | Use Case |
|----------|----------|
| `forgejo-dotnet.yml` | .NET projects (test + Docker) |
| `forgejo-node.yml` | Node.js projects (test + Docker) |
| `forgejo-kustomize-deploy.yml` | Kubernetes deploy with kustomize |
| `forgejo-ci.yml` | Generic CI template |
| `forgejo-ci-simple.yml` | Minimal CI |

## Conventions

### Job Naming
Use `{app} / {task}` format:
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
SDK images don't have Node.js, so use git clone instead of actions/checkout:
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
- `FORGEJO_TOKEN` - For git clone and Docker registry
- `KUBE_CONFIG` - Base64 encoded kubeconfig for deploys

## AGENTS.md
Use `AGENTS-TEMPLATE.md` as starting point for repo-specific agent instructions.
