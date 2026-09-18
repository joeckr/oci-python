ARG IMAGE=alpine
ARG TAG=3.24
ARG REGISTRY=docker.io/library
FROM ghcr.io/astral-sh/uv:0.12-python3.14-alpine AS builder

WORKDIR /app

COPY src/pyproject.toml src/uv.lock ./

RUN uv sync --frozen --no-dev

COPY src/. .

FROM $REGISTRY/$IMAGE:$TAG

ARG VERSION=3.14

RUN apk add --no-cache \
    python3~=${VERSION} \
    libstdc++~=15.2

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    mkdir -p /usr/local/bin && \
    ln -sf /usr/bin/python3 /usr/local/bin/python3

WORKDIR /app

COPY --from=builder /app /app
ENV PATH=/app/.venv/bin:$PATH

RUN chgrp -R 0 /app && \
    chmod -R g+rwX /app
USER 1031

EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000", "--proxy-headers"]
