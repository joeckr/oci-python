# Skeleton OCI Custom

This repository serves as a starter template for building, packaging, and deploying your own custom container images. It provides secure-by-default container configurations compliant with **OpenShift** (arbitrary UID support) and **Talos Linux**, automated multi-architecture CI/CD workflows, and an accompanying production-ready **Helm chart**.

## Purpose

Building custom container images for modern, security-hardened Kubernetes environments like OpenShift (enforcing strict Security Context Constraints) and Talos Linux requires adhering to strict security defaults from the start. Images must run without root privileges, avoid privilege escalation, and accommodate arbitrary user IDs.

This skeleton provides an out-of-the-box foundation to:
- **Build Custom Images**: Jumpstart development of your own containerized services and applications.
- **Enterprise Security Defaults**: Run as non-root (`USER 1031`), support OpenShift arbitrary UIDs (`chgrp -R 0` and `chmod -R g+rwX`), and satisfy restricted pod security standards.
- **Automated CI/CD**: Build multi-platform images (amd64, arm64), run vulnerability scans (Trivy), generate Software Bills of Materials (SBOM), and publish to GitHub Container Registry (GHCR) using reusable CI templates.
- **Deploy with Helm**: Deploy seamlessly with a ready-to-use Helm chart (`chart/`) supporting Kubernetes Deployments, Services, Ingress, OpenShift Routes, Persistent Volume Claims (PVC), and ConfigMaps.
- **Local Development**: Rapidly iterate and verify builds locally using Docker Compose.

## Features

- **Custom Image Starter**: Boilerplate `Dockerfile` set up to build custom application images with configurable base images and tags.
- **OpenShift Compliance**: Configured to run without root privileges and handle arbitrary user IDs gracefully.
- **Talos Linux Compatibility**: Follows security best practices suitable for immutable, secure-by-default Kubernetes operating systems.
- **Helm Chart Included**: Comes with a ready-to-use Helm chart (`chart/`) for templated, reproducible deployments.
- **Matrix CI Pipelines**: Uses `joeckr/ci-templates` workflows (`build-oci-custom.yml`, `push-helm-ghcr.yml`, `semantic.yml`) to automatically build, scan, tag, and push images and Helm charts.
- **Version Matrix Configuration**: Control target image versions, base images, and base tags via `versions.json`.
- **Local Testing**: Includes `docker-compose.yml` for local container verification.
- **Code Quality & Linting**: Pre-configured with `hk` hooks for pre-commit checks (`actionlint`, `zizmor`, `yamllint`, `helm-lint`).

## Repository Structure

- `Dockerfile`: Template Dockerfile demonstrating secure patterns (non-root user, group 0 permissions) for custom builds.
- `chart/`: Accompanying Helm chart for deploying the application to Kubernetes or OpenShift.
- `versions.json`: Build matrix defining target image version, base image, base tag, and release flags.
- `docker-compose.yml`: For local testing and development.
- `.github/workflows/`:
  - `release.yml`: Production release pipeline (semantic versioning, custom OCI build & push, Helm chart push to GHCR).
  - `test_release.yml`: PR validation pipeline running dry-run builds and test releases.
  - `lint.yml`: Validates workflows, Helm charts, and repository code.
  - `security.yml`: Code and dependency security scanning.
- `hk.pkl`: Pre-commit hook configuration managed with `hk`.

## Getting Started

### 1. Use as a Template
Clone or use this repository as a template for your own custom image project:
```bash
git clone https://github.com/joeckr/skeleton-oci.git my-custom-image
cd my-custom-image
```

### 2. Customize the Dockerfile
Update `Dockerfile` with your application dependencies, build stages, or assets. The template is pre-configured with base image arguments:
```dockerfile
ARG IMAGE=nginx
ARG TAG=1.31.5-alpine
ARG REGISTRY=docker.io/library
FROM $REGISTRY/$IMAGE

ARG VERSION=1.31.5
...
```

Ensure any writable directories maintain non-root and OpenShift arbitrary UID compatibility:
```dockerfile
RUN chgrp -R 0 /app && \
    chmod -R g+rwX /app

USER 1031
```

### 3. Configure the Build Matrix
Define the versions you want to build in `versions.json`:
```json
[
  {
    "version": "1.31.5",
    "base-image": "nginx",
    "base-tag": "1.31.5-alpine",
    "latest": true,
    "lts": false
  }
]
```
The CI workflow passes `VERSION` (`matrix.version.version`), `IMAGE` (`matrix.version.base-image`), and `TAG` (`matrix.version.base-tag`) directly into the Docker build as build arguments.

### 4. Configure CI Workflows
In `.github/workflows/release.yml` and `.github/workflows/test_release.yml`, update the `image` input to match your target image name:
```yaml
uses: joeckr/ci-templates/.github/workflows/build-oci-custom.yml@...
with:
  image: "my-custom-image"
```

### 5. Update the Helm Chart
Navigate to the `chart/` directory and update `Chart.yaml` and `values.yaml` to reflect your application name, container image path, port configurations, and ingress settings.

### 6. Test Locally
Build and run the container locally with Docker Compose:
```bash
docker compose up --build
```

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
