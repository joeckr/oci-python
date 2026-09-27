# OCI Python

This repository serves as a lightweight, secure-by-default Python container image starter template. Built on Alpine Linux and packaged with Astral's [`uv`](https://github.com/astral-sh/uv) package manager, it provides an enterprise-ready runtime environment for Python and FastAPI applications. It is pre-configured for compliance with modern Kubernetes security standards (restricted Pod Security Standards and arbitrary non-root UID support), automated multi-architecture CI/CD workflows, and an accompanying **Helm chart**.

## Purpose

Running containerized Python workloads in security-hardened Kubernetes environments (enforcing restricted Pod Security Standards and rootless runtimes) requires adhering to strict security defaults. Containers must run without root privileges, avoid privilege escalation, and accommodate arbitrary user IDs while maintaining minimal image footprints.

This repository provides an out-of-the-box foundation to:
- **Minimal Python Runtime**: Multi-stage Docker build separating the build toolchain (`uv`) from the production runtime, yielding a lean Alpine image (~55 MB) free of development compilers.
- **Enterprise Security Defaults**: Runs as non-root (`USER 1031`), supports arbitrary dynamic UIDs (`chgrp -R 0 /app` and `chmod -R g+rwX /app`), and satisfies restricted Pod Security Standards.
- **Modern Python Packaging**: Uses Astral `uv` for lightning-fast lockfile resolution, dependency caching, and virtual environment management via `pyproject.toml` and `uv.lock`.
- **FastAPI Starter**: Includes a production-ready FastAPI boilerplate application in `src/` configured with `--proxy-headers` for reverse proxy compatibility.
- **Automated CI/CD**: Build multi-platform images (amd64, arm64), run vulnerability scans (Trivy), generate Software Bills of Materials (SBOM), and publish to GitHub Container Registry (GHCR) using reusable CI templates.
- **Deploy with Helm**: Deploy seamlessly with a ready-to-use Helm chart (`chart/`) supporting Kubernetes Deployments, Services, and custom security contexts.
- **Local Development**: Rapidly iterate locally using Docker Compose or task workflows via `mise`.

## Features

- **Fast Multi-Stage Builds**: Pre-builds dependencies in a `uv`-powered builder stage and copies the isolated virtual environment into a lightweight Alpine runtime.
- **Optimized Layer Caching**: Separate lockfile copying and dependency synchronization ensures dependency layers remain cached when application code changes.
- **Rootless & Hardened Image Design**: Configured with group 0 permissions and non-root execution (`USER 1031`).
- **Helm Chart Included**: Standardized Kubernetes deployment templates in `chart/` for rapid cluster onboarding.
- **Matrix CI Pipelines**: Integrates with `joeckr/ci-templates` workflows (`build-oci-custom.yml`, `push-helm-ghcr.yml`, `semantic.yml`) for semantic versioning, Trivy vulnerability scanning, and GHCR publishing.
- **Tooling & Task Management**: Includes `mise.toml` tasks for building, running, and scanning, as well as `hk` pre-commit hooks for code quality.

## Repository Structure

- `Dockerfile`: Multi-stage Dockerfile leveraging `uv` for dependency installation and a hardened Alpine Linux runtime.
- `src/`: Application source code and Python project definitions.
  - `main.py`: FastAPI application entrypoint.
  - `pyproject.toml`: Python project metadata and dependencies.
  - `uv.lock`: Deterministic dependency lockfile managed by `uv`.
- `chart/`: Helm chart for deploying the Python service to Kubernetes.
- `versions.json`: Build matrix defining target image version, base image, base tag, and release flags.
- `compose.yml`: Local multi-container orchestration for testing.
- `mise.toml`: Local tool definitions and task runner (`mise run compose`, `mise run build`, etc.).
- `.github/workflows/`:
  - `release.yml`: Production release pipeline (semantic release, OCI build & push to GHCR, Helm chart push).
  - `test_release.yml`: PR validation pipeline running test builds and scans.
  - `lint.yml`: Validates workflows, Helm charts, and code formatting.
  - `security.yml`: Trivy and secret scanning workflows.
- `hk.pkl`: Pre-commit hook configuration managed by `hk`.

## Getting Started

### Prerequisites

- [Podman](https://podman.io/) (or [Docker](https://docs.docker.com/get-docker/)) & Podman Compose
- [uv](https://github.com/astral-sh/uv) (for local Python development)
- [mise](https://mise.jdx.dev/) (for task automation and tool versioning)

### 1. Local Python Development

For local development outside Docker, use `uv` directly from the `src/` directory:

```bash
cd src

# Install dependencies into local .venv
uv sync

# Start FastAPI development server with auto-reload
uv run fastapi dev
```

The application will be available at `http://localhost:8000`.

## Security & Hardened Image Architecture

Modern hardened Kubernetes environments prioritize workload security and least privilege by enforcing strict runtime constraints. This repository is architected to produce rootless, hardened container images that run out-of-the-box under restricted security standards without requiring root privileges.

### Hardened Container Standards (Kubernetes PSS `restricted`)

Under the Kubernetes **Pod Security Admission (PSA)** `restricted` profile and modern hardened container runtimes:
- **Must Run As Non-Root**: The pod specification sets `securityContext.runAsNonRoot: true` with a dedicated non-root UID (`USER 1031` or dynamic non-root UID). Containers cannot execute as UID 0.
- **Arbitrary Dynamic UIDs**: Workload environments may assign dynamic arbitrary non-root UIDs. Files and directories required at runtime are configured with group 0 permissions (`chgrp -R 0` and `chmod -R g+rwX`) so any non-root UID can execute and access required assets.
- **Drop All Capabilities**: The container specification explicitly drops all Linux capabilities (`capabilities.drop: ["ALL"]`).
- **Disallow Privilege Escalation**: Pods enforce `securityContext.allowPrivilegeEscalation: false` to prevent child processes from acquiring additional privileges.
- **RuntimeDefault Seccomp**: Workloads enforce `seccompProfile: { type: RuntimeDefault }` to restrict syscalls to safe defaults.
- **Credential Protection**: Hardened with `automountServiceAccountToken: false` to avoid leaking Kubernetes API tokens to application containers unless explicitly needed.
- **Unprivileged Ports**: Containers listen on non-privileged ports (> 1024).
- **Standard Ingress & Storage**: Uses standard Kubernetes `networking.k8s.io/v1` `Ingress` and standard CSI PersistentVolumeClaims.

### Rootless Build Environment Compliance

Building container images inside secure or unprivileged environments (such as rootless Podman/Buildah on developer workstations, or unprivileged Kubernetes CI runners like Tekton or Kaniko) requires that the build process itself does not rely on host `root` privileges or the legacy root-owned Docker daemon socket (`/var/run/docker.sock`).

This repository's `Dockerfile` is engineered for complete rootless build support:
- **No Host Root Required**: Builds execute and succeed cleanly under unprivileged user namespaces without needing `sudo` or privileged container builders.
- **User Namespace Friendly Permissions**: Layer modifications rely on `chgrp -R 0` and group-based permissions (`g+rwX`), which map cleanly into subordinate UID/GID allocations (`/etc/subuid` and `/etc/subgid`) without failing on host-restricted `chown` operations.
- **Atomic Multi-Stage Copy**: Pre-builds dependencies in a `uv` stage and copies isolated artifacts into a clean runtime stage owned by group 0.
- **Unprivileged Local Build**: Run `mise run build` (`podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/python:test . --load`) or `mise run compose` to build locally without root escalation.

### Compliance Matrix

| Security Dimension | Restricted Standard Requirement | Implementation in This Repo |
|---|---|---|
| **Build Execution** | Unprivileged / rootless builder compatible | Builds unprivileged via rootless Podman/Buildah (`mise run build`) |
| **User ID** | Non-root UID (`runAsNonRoot: true`) / dynamic UID | `USER 1031` in Dockerfile + `runAsNonRoot: true` in Helm |
| **Group Permissions** | GID 0 (`root` group) with `g+rwX` | `chgrp -R 0 /app` & `chmod -R g+rwX /app` on runtime paths |
| **Capabilities** | Must drop `ALL` capabilities | `capabilities.drop: ["ALL"]` in Helm chart |
| **Privilege Escalation** | Prohibited (`allowPrivilegeEscalation: false`) | Configured in Helm `securityContext` |
| **Seccomp Profile** | `RuntimeDefault` or `Localhost` | `seccompProfile: { type: RuntimeDefault }` |
| **Service Account Token** | Disabled unless required | Hardened in pod configuration |
| **Port Binding** | Unprivileged (> 1024) | Listens on port `8000` (Compose) / `8080` (Helm) |
---

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to hardened Kubernetes environments, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to enforce rootless and hardened container runtime restrictions in testing:

| Security Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted profiles). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

---

## Testing & Validation Process

This repository defines a 3-tier testing process to validate container security, manifest generation, and runtime compatibility from local development through to production cluster deployment.

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│ Tier 1: Local Test      │ ──> │ Tier 2: Podman Play     │ ──> │ Tier 3: K8s Cluster     │
│ Verify non-root & app   │     │ Validate K8s manifests  │     │ Live Helm verification  │
│ (compose.yml)           │     │ (podman play kube)      │     │ (helm install)          │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

### Tier 1: Local Container Validation (`compose.yml`)

The [`compose.yml`](compose.yml) configuration builds and runs the customized `Dockerfile` containing the adaptations required for rootless, hardened container execution:

```sh
# Build and start the container
mise run compose
# or: podman compose up -d --build

# View container logs
mise run logs
# or: podman compose logs -f

# Verify connectivity
curl http://localhost:8000

# Stop compose stack
mise run down
# or: podman compose down
```

**What this verifies:**
- Rootless multi-stage image build and layer assembly without host root privileges.
- Non-root user execution (`USER 1031`).
- Root group ownership (`chgrp -R 0 /app`) and group read/write permissions (`chmod -R g+rwX /app`).
- Unprivileged port binding (`8000`).
- FastAPI server initialization and healthy response.

---

### Tier 2: Local Kubernetes Manifest Testing (`mise run play`)

Before deploying to an actual Kubernetes cluster, you can test the rendered Kubernetes manifests locally using Podman's built-in `play kube` feature.

```sh
# Render templates and play Kubernetes manifests locally
mise run play

# Teardown the played pod and resources
mise run play-d
```

**How `mise run play` works:**
1. Triggers the dependent task `mise run helm-t`, which executes:
   ```sh
   helm dependency build chart/
   helm template test chart/ > rendered.yaml
   ```
2. Executes `podman play kube rendered.yaml --publish-all`, which:
   - Reads the multi-document Kubernetes YAML (`Service`, `Deployment`).
   - Creates a local Podman pod matching the Kubernetes `Deployment` specification.
   - Applies the pod's `securityContext` (`runAsNonRoot: true`, capabilities drop, seccomp profile).
   - Exposes container port `8080`.

**Inspecting the local play deployment:**
```sh
# View running pods created by play kube
podman pod ps

# View container status within the pod
podman ps --filter "pod=oci-python"

# Verify the service responds
curl http://localhost:8080

# Check container logs within the pod
podman logs -f oci-python-pod-oci-python
```

**Teardown:**
```sh
mise run play-d
# or: podman play kube rendered.yaml --down
```

---

### Tier 3: Cluster Deployment & Testing on Kubernetes (`mise run helm-i`)

The final phase validates the workload on a live Kubernetes cluster. This tests real-world Pod Security Admission (PSA) enforcement, network policies, and service routing.

#### 1. Cluster Prerequisites & Configuration

Ensure your `kubectl` context points to your Kubernetes cluster:
```sh
kubectl config current-context
```

Ensure the container image is accessible to your cluster nodes (e.g., built and pushed to GitHub Container Registry `ghcr.io` or your local registry):
```sh
# Build image locally with target tag
mise run build
```

#### 2. Linting & Template Validation

```sh
# Lint the chart for syntax and formatting errors
mise run helm-l

# Inspect the rendered manifests before installation
mise run helm-t
cat rendered.yaml
```

#### 3. Deploying to the Cluster

Install the Helm chart release:
```sh
mise run helm-i
# or: helm install test chart/
```

#### 4. Verifying PSS Compliance & Health

Check the pod status and verify that Kubernetes Pod Security Admission (PSA) allowed the pod to run:

```sh
# Check pod deployment status
kubectl get pods -l app=oci-python

# Inspect pod details and events for security policy rejections
kubectl describe pod -l app=oci-python
```

> [!TIP]
> If your namespace enforces the `restricted` Pod Security Standard and there are non-compliant settings (such as missing `runAsNonRoot` or un-dropped capabilities), `kubectl describe pod` will show warning events from the `pod-security` admission controller.

Check the application logs:
```sh
kubectl logs -l app=oci-python -f
```

Verify network access via port-forwarding:
```sh
kubectl port-forward svc/template-service 8080:8080
# In another terminal:
curl http://localhost:8080
```

#### 5. Uninstalling from the Cluster

When testing is complete, clean up the release:
```sh
mise run helm-u
# or: helm uninstall test
```

---

### 3. Build & Scan Image

Using `mise` tasks to test building and security scanning locally:

```bash
# Build local test image
mise run build

# Run Trivy vulnerability scan against the built image
mise run trivy-i

# Run Trivy filesystem scan
mise run trivy-fs
```

### 4. Customizing the Dockerfile

The `Dockerfile` employs a multi-stage build pattern:

1. **Builder stage**: Uses `ghcr.io/astral-sh/uv` to install dependencies into `/app/.venv` using `uv sync --frozen --no-dev`.
2. **Runtime stage**: Starts from a clean Alpine image, installs runtime `python3` and `libstdc++`, sets up required symlinks, sets group 0 permissions, and switches to non-root `USER 1031`.

```dockerfile
ARG IMAGE=alpine
ARG TAG=3.24
ARG REGISTRY=docker.io/library
FROM ghcr.io/astral-sh/uv:0.12-python3.14-alpine AS builder

WORKDIR /app
COPY src/pyproject.toml src/uv.lock ./
RUN uv sync --frozen --no-dev
COPY src/. .

FROM $REGISTRY/$IMAGE:$TAG
RUN apk add --no-cache python3 libstdc++ && \
    mkdir -p /usr/local/bin && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/python3 /usr/local/bin/python3

WORKDIR /app
COPY --from=builder /app /app
ENV PATH=/app/.venv/bin:$PATH

RUN chgrp -R 0 /app && chmod -R g+rwX /app
USER 1031

EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000", "--proxy-headers"]
```

### 5. Configure Build Matrix

Update `versions.json` to define the target base image and version tags:

```json
[
  {
    "version": "0.1.0",
    "base-image": "alpine",
    "base-tag": "3.24",
    "latest": true,
    "lts": false
  }
]
```

### 6. Run the Test Suite

Validate changes through the 3-tier process: `mise run compose` (local container validation), `mise run play` (manifest test), and `mise run helm-i` (Kubernetes cluster test).

## Code Quality & Hooks

This project uses [`mise`](https://mise.jdx.dev/) for task execution and [`hk`](https://github.com/jdx/hk) for pre-commit quality enforcement:

```bash
# Setup tools and git hooks
mise run install

# Run all linters and hook checks
mise run hk # or mise run check
```

### Available mise Tasks

The following tasks are defined in [`mise.toml`](mise.toml):

| Task | Description | Command |
|---|---|---|
| `install` | Install Git hooks (`pre-commit` and `commit-msg`). | `hk install --mise` |
| `hk` (or `check`) | Run all checks across the repository. | `hk check --all` |
| `compose` | Start local container environment with Podman Compose. | `podman compose up -d --build` |
| `down` | Stop local Podman Compose stack. | `podman compose down` |
| `logs` | Follow Podman Compose logs. | `podman compose logs -f` |
| `play` | Test Helm chart manifests locally with Podman Play Kube. | `podman play kube rendered.yaml --publish-all` |
| `play-d` | Stop and tear down Podman Play Kube pods. | `podman play kube rendered.yaml --down` |
| `helm-d` | Build Helm chart dependencies. | `helm dependency build chart/` |
| `helm-l` | Lint the Helm chart. | `helm lint chart/` |
| `helm-t` | Render Helm chart templates to `rendered.yaml`. | `helm template test chart/ > rendered.yaml` |
| `helm-i` | Install the Helm chart to the current Kubernetes cluster. | `helm install test chart/` |
| `helm-u` | Uninstall the Helm chart release from the cluster. | `helm uninstall test` |
| `build` | Build local test container image for `linux/amd64`. | `podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/python:test . --load` |
| `trivy-fs` | Scan local repository filesystem for security vulnerabilities. | `trivy fs .` |
| `trivy-i` | Build image and run Trivy vulnerability scan on container. | `trivy image ghcr.io/joeckr/python:test` |

Checks run by `hk` include `hadolint`, `yamllint`, `actionlint`, `tombi`, `betterleaks`, and `shellcheck`.

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
