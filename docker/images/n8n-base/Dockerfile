# Dockerfile for n8n.io
# Source: https://github.com/n8n-io/n8n/blob/master/docker/images/n8n-base/Dockerfile
# Advanced Multi-Stage Build for Render.com deployment from repository root (Root Directory: ./)
# This Dockerfile handles n8n's monorepo structure by copying the entire repo in an early stage,
# and implementing a flattening fix for problematic nested COPY operations.

ARG NODE_VERSION=22
ARG N8N_VERSION=snapshot
ARG LAUNCHER_VERSION=1.1.3
ARG TARGETPLATFORM=linux/amd64

# ==============================================================================
# STAGE 0: Copy Repo and Flatten Assets
# ==============================================================================
FROM alpine:latest AS repo-copy
WORKDIR /repo_root
COPY . .

# Flatten problem files into /build-assets to avoid BuildKit checksum errors
RUN mkdir -p /repo_root/build-assets && \
    cp /repo_root/docker/images/n8n/docker-entrypoint.sh /repo_root/build-assets/ && \
    cp /repo_root/docker/images/n8n/n8n-task-runners.json /repo_root/build-assets/

# ==============================================================================
# STAGE 1: Base Builder
# ==============================================================================
FROM node:${NODE_VERSION}-alpine AS builder
RUN echo "DEBUG: TARGETPLATFORM is -> $TARGETPLATFORM <-"

# Install fonts
RUN apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \;

# System dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        git \
        openssh \
        openssl \
        graphicsmagick=1.3.45-r0 \
        tini=0.19.0-r3 \
        tzdata \
        ca-certificates \
        libc6-compat=1.1.0-r4 \
        jq=1.8.0-r0

# NPM updates
RUN npm install -g full-icu@1.5.0 npm@11.4.2 && \
    rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn* && \
    apk del apk-tools

# ==============================================================================
# STAGE 2: Build App
# ==============================================================================
FROM node:${NODE_VERSION} AS build-app
WORKDIR /n8n

# Copy entire monorepo
COPY --from=repo-copy /repo_root /n8n

# Install dependencies and build app
RUN corepack enable && \
    corepack prepare pnpm@latest --activate && \
    pnpm install && \
    pnpm build --verbosity 1

# ==============================================================================
# STAGE 3: Download Task Runner Launcher
# ==============================================================================
FROM alpine:3.22.0 AS launcher-downloader-stage

ARG TARGETPLATFORM
ARG LAUNCHER_VERSION

RUN set -e; \
    ARCH_NAME="amd64"; \
    mkdir /launcher-temp && cd /launcher-temp; \
    wget -q "https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz"; \
    wget -q "https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz.sha256"; \
    echo "$(cat task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz.sha256) task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz" > checksum.sha256; \
    sha256sum -c checksum.sha256; \
    mkdir -p /launcher-bin; \
    tar xzf task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz -C /launcher-bin; \
    cd / && rm -rf /launcher-temp

# ==============================================================================
# STAGE 4: Final Runtime Image
# ==============================================================================
FROM node:${NODE_VERSION}-alpine AS runtime

ARG N8N_VERSION
ARG N8N_RELEASE_TYPE=dev

ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}
ENV NODE_ICU_DATA=/usr/local/lib/node_modules/full-icu
ENV SHELL=/bin/sh

WORKDIR /home/node

# Copy built app
COPY --from=build-app /n8n /usr/local/lib/node_modules/n8n

# Copy launcher binaries
COPY --from=launcher-downloader-stage /launcher-bin/* /usr/local/bin/

# Copy entrypoint and task runners
COPY --from=repo-copy /repo_root/build-assets/docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=repo-copy /repo_root/build-assets/n8n-task-runners.json /etc/n8n-task-runners.json

RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 --unsafe-perm && \
    ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

RUN cd /usr/local/lib/node_modules/n8n/node_modules/pdfjs-dist && \
    npm install @napi-rs/canvas

EXPOSE 5678/tcp
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/n8n-io/n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version=${N8N_VERSION}