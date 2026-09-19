# OCI Python

This repository serves as a lightweight, secure-by-default Python container image starter template. Built on Alpine Linux and packaged with Astral's [`uv`](https://github.com/astral-sh/uv) package manager, it provides an enterprise-ready runtime environment for Python and FastAPI applications. It is pre-configured for compliance with **OpenShift** (arbitrary UID support) and **Talos Linux**, automated multi-architecture CI/CD workflows, and an accompanying **Helm chart**.

## Purpose

Running containerized Python workloads in security-hardened Kubernetes environments like OpenShift (enforcing strict Security Context Constraints) and Talos Linux requires adhering to strict security defaults. Containers must run without root privileges, avoid privilege escalation, and accommodate arbitrary user IDs while maintaining minimal image footprints.

This repository provides an out-of-the-box foundation to:
- **Minimal Python Runtime**: Multi-stage Docker build separating the build toolchain (`uv`) from the production runtime, yielding a lean Alpine image (~55 MB) free of development compilers.
- **Enterprise Security Defaults**: Runs as non-root (`USER 1031`), supports OpenShift arbitrary UIDs (`chgrp -R 0 /app` and `chmod -R g+rwX /app`), and satisfies restricted Pod Security Standards.
- **Modern Python Packaging**: Uses Astral `uv` for lightning-fast lockfile resolution, dependency caching, and virtual environment management via `pyproject.toml` and `uv.lock`.
- **FastAPI Starter**: Includes a production-ready FastAPI boilerplate application in `src/` configured with `--proxy-headers` for reverse proxy compatibility.
- **Automated CI/CD**: Build multi-platform images (amd64, arm64), run vulnerability scans (Trivy), generate Software Bills of Materials (SBOM), and publish to GitHub Container Registry (GHCR) using reusable CI templates.
- **Deploy with Helm**: Deploy seamlessly with a ready-to-use Helm chart (`chart/`) supporting Kubernetes Deployments, Services, and custom security contexts.
- **Local Development**: Rapidly iterate locally using Docker Compose or task workflows via `mise`.

## Features

- **Fast Multi-Stage Builds**: Pre-builds dependencies in a `uv`-powered builder stage and copies the isolated virtual environment into a lightweight Alpine runtime.
- **Optimized Layer Caching**: Separate lockfile copying and dependency synchronization ensures dependency layers remain cached when application code changes.
- **OpenShift & Kubernetes Hardened**: Configured with OpenShift group 0 permissions and non-root execution (`USER 1031`).
- **Helm Chart Included**: Standardized Kubernetes deployment templates in `chart/` for rapid cluster onboarding.
- **Matrix CI Pipelines**: Integrates with `joeckr/ci-templates` workflows (`build-oci-custom.yml`, `push-helm-ghcr.yml`, `semantic.yml`) for semantic versioning, Trivy vulnerability scanning, and GHCR publishing.
- **Tooling & Task Management**: Includes `mise.toml` tasks for building, running, and scanning, as well as `hk` pre-commit hooks for code quality.

## Repository Structure

- `Dockerfile`: Multi-stage Dockerfile leveraging `uv` for dependency installation and a hardened Alpine Linux runtime.
- `src/`: Application source code and Python project definitions.
  - `main.py`: FastAPI application entrypoint.
  - `pyproject.toml`: Python project metadata and dependencies.
  - `uv.lock`: Deterministic dependency lockfile managed by `uv`.
- `chart/`: Helm chart for deploying the Python service to Kubernetes or OpenShift.
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

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to OpenShift or Talos Linux, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to simulate OpenShift's default **`restricted-v2` Security Context Constraints (SCC)**:

| OpenShift SCC Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted SCC). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

## Testing with Podman Compose

The [`compose.yml`](compose.yml) file builds and runs the container with the security adaptations required for OpenShift and Talos Linux:

```sh
# Build and start the container
podman compose up -d --build

# Or via mise
mise run compose
```

This verified configuration applies:
- Non-root user execution (`USER 1031`).
- Root group ownership (`chgrp -R 0`) and group read/write permissions (`chmod -R g+rwX`) on `/app`.
- Production-ready FastAPI service running unprivileged on port `8000`.

### Stopping Containers & Viewing Logs

```sh
# Stop compose stack
podman compose down
# or: mise run down

# View logs
podman compose logs -f
# or: mise run logs
```

### Local Helm Testing (Podman Play Kube)

Test rendered Helm chart manifests directly in Podman without requiring a remote cluster:

```sh
# Render Helm template and run pods locally via podman play kube
mise run play

# Stop and tear down local pods
mise run downplay
```

### 3. Build & Scan Image

Using `mise` tasks to test building and security scanning locally:

```bash
# Build local test image
mise run build

# Run Trivy vulnerability scan against the built image
mise run trivy-image

# Run Trivy filesystem scan
mise run trivy-fs
```

### 4. Customizing the Dockerfile

The `Dockerfile` employs a multi-stage build pattern:

1. **Builder stage**: Uses `ghcr.io/astral-sh/uv` to install dependencies into `/app/.venv` using `uv sync --frozen --no-dev`.
2. **Runtime stage**: Starts from a clean Alpine image, installs runtime `python3` and `libstdc++`, sets up required symlinks, sets OpenShift group permissions, and switches to non-root `USER 1031`.

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

### 6. Helm Deployment

The accompanying Helm chart in `chart/` is pre-configured to deploy the service with non-root security contexts:

```bash
helm template my-app chart/
```

Update `chart/values.yaml` to configure replica counts, resource requests/limits, image repository, and ports as needed for your target cluster.

---

## OpenShift Security & Podman Local Simulation

Hardened container environments such as Red Hat OpenShift enforce strict Security Context Constraints (such as `restricted` and `restricted-v2` SCCs) that prevent containers from running as root, mapping host root, or using elevated capabilities.

This container image adheres to these principles:
- Runs unprivileged under non-root user `USER 1031`.
- Sets group 0 permissions (`chgrp -R 0 /app && chmod -R g+rwX /app`), allowing execution under arbitrary dynamic UIDs assigned by OpenShift.
- Exposes unprivileged port `8000`.

---

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

| Task | Command | Description |
|---|---|---|
| `mise run install` | `hk install --mise` | Install Git hooks (`pre-commit` and `commit-msg`). |
| `mise run hk` *(or `check`)* | `hk check --all` | Run all checks across the repository. |
| `mise run compose` | `podman compose up -d --build` | Start local container environment with Podman Compose. |
| `mise run down` | `podman compose down` | Stop local Podman Compose stack. |
| `mise run logs` | `podman compose logs -f` | Follow Podman Compose logs. |
| `mise run play` | `podman play kube rendered.yaml` | Test Helm chart manifests locally with Podman Play Kube. |
| `mise run downplay` | `podman play kube rendered.yaml --down` | Stop and tear down Podman Play Kube pods. |
| `mise run helm-lint` | `helm lint chart/` | Lint the Helm chart. |
| `mise run helm-template` | `helm template test chart/ > rendered.yaml` | Render Helm chart templates to `rendered.yaml`. |
| `mise run helm-dep` | `helm dependency build chart/` | Build Helm chart dependencies. |
| `mise run trivy-fs` | `trivy fs .` | Scan local repository filesystem for security vulnerabilities. |
| `mise run build` | `podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/python:test . --load` | Build local test container image for `linux/amd64`. |
| `mise run trivy-image` | `trivy image ghcr.io/joeckr/python:test` | Build image and run Trivy vulnerability scan on container. |

Checks run by `hk` include `hadolint`, `yamllint`, `actionlint`, `tombi`, `betterleaks`, and `shellcheck`.

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
