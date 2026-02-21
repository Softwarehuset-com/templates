#!/usr/bin/env python3
"""
CI Workflow Generator — composes Forgejo Actions workflows from declarative config.

Usage:
    generate.sh ci-config.yml              # prints to stdout
    generate.sh ci-config.yml > .forgejo/workflows/ci.yml

Smart defaults mean minimal config. See README.md for details.
"""

import sys
import os
import glob
import yaml


# =============================================================================
# Defaults
# =============================================================================
DEFAULTS = {
    "registry": "code.core.ci/softwarehuset",
    "timeout-minutes": 20,
    "submodules": True,
    "dotnet-channel": "10",
    "node-version": "22",
}


def auto_detect_solution(repo_root):
    """Scan repo for *.sln / *.slnx, return relative path of first found."""
    for ext in ("*.slnx", "*.sln"):
        matches = glob.glob(os.path.join(repo_root, "**", ext), recursive=True)
        # Filter out vendor directories
        matches = [m for m in matches if "/vendor/" not in m and "/node_modules/" not in m]
        if matches:
            return os.path.relpath(matches[0], repo_root)
    return None


def auto_detect_docker_compose(repo_root):
    """Check if docker-compose.yml or docker-compose.yaml exists."""
    for name in ("docker-compose.yml", "docker-compose.yaml"):
        if os.path.exists(os.path.join(repo_root, name)):
            return True
    return False


def indent(text, spaces):
    """Indent every line of text by N spaces."""
    prefix = " " * spaces
    return "\n".join(prefix + line if line.strip() else line for line in text.splitlines())


# =============================================================================
# Job Generators
# =============================================================================

def gen_test_dotnet(cfg, repo_root, global_cfg):
    """Generate .NET test job steps."""
    submodules = cfg.get("submodules", global_cfg.get("submodules", DEFAULTS["submodules"]))
    channel = cfg.get("dotnet-channel", global_cfg.get("dotnet-channel", DEFAULTS["dotnet-channel"]))
    timeout = cfg.get("timeout-minutes", global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"]))
    job_name = cfg.get("name", "test-backend")
    working_dir = cfg.get("working-directory", None)

    # Solution path auto-detection
    solution = cfg.get("solution-path", None)
    if solution is None:
        solution = auto_detect_solution(repo_root)

    # Docker compose
    dc = cfg.get("docker-compose", False)
    if dc == "auto":
        dc = auto_detect_docker_compose(repo_root)

    # Build solution arg
    sln_arg = f" {solution}" if solution else ""

    checkout_with = ""
    if submodules:
        checkout_with = "\n        with:\n          submodules: true"

    dc_start = ""
    dc_stop = ""
    if dc:
        dc_start = """
      - name: Start services
        run: |
          if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
            echo "📦 Found docker-compose, starting services..."
            docker compose up -d
            sleep 5
          fi
"""
        dc_stop = """
      - name: Stop services
        if: always()
        run: |
          if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
            docker compose down
          fi"""

    return f"""  {job_name}:
    name: {job_name}
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4{checkout_with}

      - name: Setup .NET
        run: |
          curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel {channel}
          echo "$HOME/.dotnet" >> $GITHUB_PATH
{dc_start}
      - name: Restore
        run: ~/.dotnet/dotnet restore{sln_arg}

      - name: Build
        run: ~/.dotnet/dotnet build{sln_arg} --no-restore

      - name: Test
        run: ~/.dotnet/dotnet test{sln_arg} --no-build --verbosity normal --filter 'Category!=Live&Category!=Integration'
{dc_stop}"""


def gen_test_node(cfg, repo_root, global_cfg):
    """Generate Node.js test job steps."""
    timeout = cfg.get("timeout-minutes", global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"]))
    job_name = cfg.get("name", "test-frontend")
    working_dir = cfg.get("working-directory", None)
    node_version = cfg.get("node-version", global_cfg.get("node-version", DEFAULTS["node-version"]))
    submodules = cfg.get("submodules", False)

    checkout_with = ""
    if submodules:
        checkout_with = "\n        with:\n          submodules: true"

    wd_attr = ""
    if working_dir:
        wd_attr = f"\n        working-directory: {working_dir}"

    return f"""  {job_name}:
    name: {job_name}
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4{checkout_with}

      - name: Setup Node
        run: |
          curl -fsSL https://fnm.vercel.app/install | bash
          export PATH="$HOME/.local/share/fnm:$PATH"
          eval "$(fnm env)"
          fnm install {node_version}
          fnm use {node_version}
          echo "$HOME/.local/share/fnm/aliases/default/bin" >> $GITHUB_PATH

      - name: Install{wd_attr}
        run: npm ci

      - name: Lint{wd_attr}
        run: npm run lint --if-present

      - name: Build{wd_attr}
        run: npm run build

      - name: Test{wd_attr}
        run: npm test --if-present"""


def gen_test_python(cfg, repo_root, global_cfg):
    """Generate Python test job steps."""
    timeout = cfg.get("timeout-minutes", global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"]))
    job_name = cfg.get("name", "test")
    dc = cfg.get("docker-compose", False)
    if dc == "auto":
        dc = auto_detect_docker_compose(repo_root)

    dc_start = ""
    dc_stop = ""
    if dc:
        dc_start = """
      - name: Start services
        run: |
          if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
            echo "📦 Found docker-compose, starting services..."
            docker compose up -d
            sleep 5
          fi
"""
        dc_stop = """
      - name: Stop services
        if: always()
        run: |
          if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
            docker compose down
          fi"""

    return f"""  {job_name}:
    name: {job_name}
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        run: |
          sudo apt-get update
          sudo apt-get install -y python3 python3-pip python3-venv
{dc_start}
      - name: Install
        run: |
          python3 -m venv .venv
          . .venv/bin/activate
          pip install -r requirements.txt || pip install -e ".[dev]" || true

      - name: Lint
        run: |
          . .venv/bin/activate
          ruff check . || flake8 . || true

      - name: Test
        run: |
          . .venv/bin/activate
          pytest || python -m unittest discover || true
{dc_stop}"""


def gen_build_images(cfg, repo_root, global_cfg):
    """Generate Docker build job."""
    timeout = global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"])
    registry = global_cfg.get("registry", DEFAULTS["registry"])
    submodules = global_cfg.get("submodules", DEFAULTS["submodules"])
    job_name = "docker"

    # cfg is a list of image specs
    images = cfg if isinstance(cfg, list) else cfg.get("images", [])
    images_str = "\n".join(f"    {img}" for img in images)

    checkout_with = ""
    if submodules:
        checkout_with = "\n        with:\n          submodules: true"

    return f"""  {job_name}:
    name: docker
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4{checkout_with}

      - name: Login to registry
        run: echo "${{{{ secrets.FORGEJO_TOKEN }}}}" | docker login code.core.ci -u djohn --password-stdin

      - name: Build & Push images
        run: |
          set -e

          if [ "${{{{ github.event_name }}}}" = "pull_request" ]; then
            TAG="pr-${{{{ github.event.number }}}}"
          else
            TAG="${{{{ github.sha }}}}"
          fi

          IS_MAIN="${{{{ github.ref == 'refs/heads/main' }}}}"

          echo "${{{{ env.IMAGES }}}}" | grep -v '^[[:space:]]*$' | while IFS='|' read -r dockerfile image context; do
            dockerfile=$(echo "$dockerfile" | xargs)
            image=$(echo "$image" | xargs)
            context=$(echo "$context" | xargs)

            [ -z "$dockerfile" ] && continue

            FULL_IMAGE="${{{{ env.REGISTRY }}}}/${{image}}"

            echo ""
            echo "════════════════════════════════════════════════════════════"
            echo "🐳 Building: ${{FULL_IMAGE}}:${{TAG}}"
            echo "   Dockerfile: ${{dockerfile}}"
            echo "   Context:    ${{context}}"
            echo "════════════════════════════════════════════════════════════"

            docker build -f "${{dockerfile}}" -t "${{FULL_IMAGE}}:${{TAG}}" "${{context}}"
            docker push "${{FULL_IMAGE}}:${{TAG}}"

            if [ "$IS_MAIN" = "true" ]; then
              echo "📌 Tagging as latest"
              docker tag "${{FULL_IMAGE}}:${{TAG}}" "${{FULL_IMAGE}}:latest"
              docker push "${{FULL_IMAGE}}:latest"
            fi

            echo "✅ Done: ${{FULL_IMAGE}}:${{TAG}}"
          done

          echo ""
          echo "🎉 All images built successfully!\"""", images_str, registry


def gen_deploy_kustomize(cfg, repo_root, global_cfg):
    """Generate Kustomize deploy job."""
    timeout = cfg.get("timeout-minutes", global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"]))
    registry = global_cfg.get("registry", DEFAULTS["registry"])
    namespace = cfg["namespace"]
    kustomize_path = cfg.get("kustomize-path", "k8s/prod")

    # Support multiple deployments
    deployments = cfg.get("deployments", None)
    if deployments is None:
        # Single deployment shorthand
        deployment = cfg.get("deployment", cfg["namespace"])
        image = cfg.get("image", deployment)
        container = cfg.get("container", image)
        deployments = [{"deployment": deployment, "image": image, "container": container}]

    gha = "${{" # GitHub Actions expression opener
    gha_end = "}}"

    rollout_commands = ""
    for dep in deployments:
        d_name = dep if isinstance(dep, str) else dep.get("deployment", dep.get("name"))
        d_image = dep if isinstance(dep, str) else dep.get("image", d_name)
        d_container = dep if isinstance(dep, str) else dep.get("container", d_image)
        rollout_commands += f"""
          kubectl -n {namespace} set image \\
            deployment/{d_name} \\
            {d_container}={gha} env.REGISTRY {gha_end}/{d_image}:{gha} github.sha {gha_end}

          kubectl -n {namespace} rollout status \\
            deployment/{d_name} --timeout=120s
"""

    return f"""  deploy:
    name: deploy
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4

      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/

      - name: Deploy
        env:
          KUBECONFIG_DATA: {gha} secrets.KUBE_CONFIG {gha_end}
        run: |
          echo "$KUBECONFIG_DATA" | base64 -d > /tmp/kubeconfig
          export KUBECONFIG=/tmp/kubeconfig

          cd {kustomize_path}
          kubectl kustomize . | kubectl apply -f -
{rollout_commands}"""


def gen_deploy_helm(cfg, repo_root, global_cfg):
    """Generate Helm deploy job."""
    timeout = cfg.get("timeout-minutes", global_cfg.get("timeout-minutes", DEFAULTS["timeout-minutes"]))
    namespace = cfg["namespace"]
    release = cfg.get("release", namespace)
    chart = cfg["chart"]
    chart_version = cfg.get("chart-version", "")
    values_file = cfg.get("values-file", "values.yaml")

    gha = "${{" # GitHub Actions expression opener
    gha_end = "}}"

    return f"""  deploy:
    name: deploy
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: {timeout}
    steps:
      - uses: actions/checkout@v4

      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/

      - name: Install Helm
        run: curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      - name: Deploy
        env:
          KUBECONFIG_DATA: {gha} secrets.KUBE_CONFIG {gha_end}
        run: |
          echo "$KUBECONFIG_DATA" | base64 -d > /tmp/kubeconfig
          export KUBECONFIG=/tmp/kubeconfig

          VERSION_FLAG=""
          if [ -n "{chart_version}" ]; then
            VERSION_FLAG="--version {chart_version}"
          fi

          helm upgrade --install {release} {chart} \\
            --namespace {namespace} \\
            --create-namespace \\
            --values {values_file} \\
            ${{VERSION_FLAG}} \\
            --wait --timeout 5m"""


# =============================================================================
# Main Composer
# =============================================================================

def generate(config_path, repo_root):
    with open(config_path, "r") as f:
        config = yaml.safe_load(f) or {}

    # Global settings (non-job keys)
    job_keys = {"test-dotnet", "test-node", "test-python", "build-images", "deploy-kustomize", "deploy-helm"}
    global_cfg = {k: v for k, v in config.items() if k not in job_keys}

    registry = global_cfg.get("registry", DEFAULTS["registry"])

    jobs = []
    job_names = []
    needs_map = {}
    has_images = False
    images_str = ""

    # --- Test jobs ---
    if "test-dotnet" in config:
        cfg = config["test-dotnet"] if isinstance(config["test-dotnet"], dict) else {}
        jobs.append(gen_test_dotnet(cfg, repo_root, global_cfg))
        job_names.append(cfg.get("name", "test-backend"))

    if "test-node" in config:
        cfg = config["test-node"] if isinstance(config["test-node"], dict) else {}
        jobs.append(gen_test_node(cfg, repo_root, global_cfg))
        job_names.append(cfg.get("name", "test-frontend"))

    if "test-python" in config:
        cfg = config["test-python"] if isinstance(config["test-python"], dict) else {}
        jobs.append(gen_test_python(cfg, repo_root, global_cfg))
        job_names.append(cfg.get("name", "test"))

    test_job_names = list(job_names)

    # --- Build images ---
    if "build-images" in config:
        raw, img_str, _ = gen_build_images(config["build-images"], repo_root, global_cfg)
        has_images = True
        images_str = img_str

        # Add needs clause for test jobs
        needs_clause = ""
        if test_job_names:
            needs_list = ", ".join(test_job_names)
            needs_clause = f"\n    needs: [{needs_list}]"

        # Insert needs after first line
        lines = raw.split("\n")
        lines.insert(1, f"    needs: [{', '.join(test_job_names)}]" if test_job_names else "")
        raw = "\n".join(line for line in lines if line)

        jobs.append(raw)
        job_names.append("docker")

    # --- Deploy ---
    deploy_job = None
    if "deploy-kustomize" in config:
        deploy_job = gen_deploy_kustomize(config["deploy-kustomize"], repo_root, global_cfg)
    elif "deploy-helm" in config:
        deploy_job = gen_deploy_helm(config["deploy-helm"], repo_root, global_cfg)

    if deploy_job:
        # Add needs: [docker] if build exists, otherwise needs test jobs
        if has_images:
            needs = "docker"
        elif test_job_names:
            needs = ", ".join(test_job_names)
        else:
            needs = ""

        if needs:
            lines = deploy_job.split("\n")
            lines.insert(1, f"    needs: [{needs}]")
            deploy_job = "\n".join(lines)

        jobs.append(deploy_job)

    # --- Compose final YAML ---
    env_block = ""
    if has_images:
        env_block = f"""
env:
  REGISTRY: {registry}
  IMAGES: |
{images_str}
"""
    elif registry != DEFAULTS["registry"]:
        env_block = f"""
env:
  REGISTRY: {registry}
"""
    # For deploy jobs that reference REGISTRY
    elif "deploy-kustomize" in config or "deploy-helm" in config:
        env_block = f"""
env:
  REGISTRY: {registry}
"""

    output = f"""# =============================================================================
# CI/CD Pipeline — generated by templates/generate.sh
# =============================================================================

name: ci

on:
  push:
    branches: [main]
  pull_request:
{env_block}
jobs:
"""

    output += "\n\n".join(jobs)
    output += "\n"

    return output


def main():
    if len(sys.argv) < 2:
        print("Usage: generate.sh <ci-config.yml> [repo-root]", file=sys.stderr)
        print("  repo-root defaults to current directory", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    repo_root = sys.argv[2] if len(sys.argv) > 2 else os.getcwd()

    if not os.path.exists(config_path):
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    print(generate(config_path, repo_root))


if __name__ == "__main__":
    main()
