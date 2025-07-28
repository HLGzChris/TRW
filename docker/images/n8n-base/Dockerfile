# Dockerfile for n8n.io
# Source: https://github.com/n8n-io/n8n/blob/master/docker/images/n8n-base/Dockerfile
# Advanced Multi-Stage Build for Render.com deployment from repository root (Root Directory: ./)
# This Dockerfile handles n8n's monorepo structure by copying the entire repo in an early stage,
# and implementing a flattening fix for problematic nested COPY operations.

ARG NODE_VERSION=22
ARG N8N_VERSION=snapshot
ARG LAUNCHER_VERSION=1.1.3
ARG TARGETPLATFORM=linux/amd64 # Default to amd64 for common cloud platforms

# ==============================================================================
# STAGE 0: Copy Entire Repository & Flatten Problematic Files
# This stage copies the full build context (your GitHub repo root) into a known location.
# It also flattens specific deeply nested files into a temporary top-level directory
# to avoid BuildKit's COPY --from issues with complex monorepo paths.
# ==============================================================================
FROM alpine:latest AS repo-copy
WORKDIR /repo_root
COPY . .

# Flatten problematic nested files into a temporary directory for easier copying later
RUN mkdir -p /repo_root/tmp-n8n-files && \
    cp /repo_root/docker/images/n8n/docker-entrypoint.sh /repo_root/tmp-n8n-files/ && \
    cp /repo_root/docker/images/n8n/n8n-task-runners.json /repo_root/tmp-n8n-files/

# ==============================================================================
# STAGE 1: Builder for Base Dependencies
# Installs system-level dependencies and fonts.
# ==============================================================================
FROM node:${NODE_VERSION}-alpine AS builder
RUN echo "DEBUG: TARGETPLATFORM is -> $TARGETPLATFORM <-" # Debug output for platform

# Install fonts
RUN \
    apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \;

# Install essential OS dependencies (removed problematic version pins for core tools)
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

# Update npm, install full-icu (global)
RUN npm install -g full-icu@1.5.0 npm@11.4.2

RUN rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn* && \
    apk del apk-tools

# ==============================================================================
# STAGE 2: Build the App (n8n application compilation)
# This stage copies the ENTIRE repository (from repo-copy) into its working directory.
# This ensures pnpm can find package.json and all monorepo packages.
# ==============================================================================
FROM node:${NODE_VERSION} AS build-app

WORKDIR /n8n
# Copy the entire repository from the repo-copy stage into /n8n
COPY --from=repo-copy /repo_root /n8n

# Install dependencies and build the app
# Removed --frozen-lockfile to allow pnpm to update lockfile if needed
RUN corepack enable && \
    corepack prepare pnpm@latest --activate && \
    pnpm install && \
    pnpm build --verbosity 1

# ==============================================================================
# STAGE 3: Task Runner Launcher (downloads pre-built binaries)
# ==============================================================================
FROM alpine:3.22.0 AS launcher-downloader-stage

ARG TARGETPLATFORM
ARG LAUNCHER_VERSION

# Force ARCH_NAME to amd64 as TARGETPLATFORM is unreliable in some environments
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
# STAGE 4: Final Runtime Image (combines all built components)
# ==============================================================================
FROM node:${NODE_VERSION}-alpine AS runtime

ARG N8N_VERSION
ARG N8N_RELEASE_TYPE=dev
ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}
ENV NODE_ICU_DATA=/usr/local/lib/node_modules/full-icu
ENV SHELL=/bin/sh

WORKDIR /home/node

# Copy compiled n8n application from build-app stage
COPY --from=build-app /n8n /usr/local/lib/node_modules/n8n
# Copy launcher binaries
COPY --from=launcher-downloader-stage /launcher-bin/* /usr/local/bin/
# Copy entrypoint and task runners from the flattened location in repo-copy stage
COPY --from=repo-copy /repo_root/tmp-n8n-files/docker-entrypoint.sh /
COPY --from=repo-copy /repo_root/tmp-n8n-files/n8n-task-runners.json /etc/n8n-task-runners.json

RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 --unsafe-perm && \
    ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

# Install @napi-rs/canvas for pdfjs-dist (if needed, this was in original Dockerfile)
RUN cd /usr/local/lib/node_modules/n8n/node_modules/pdfjs-dist && npm install @napi-rs/canvas

EXPOSE 5678/tcp
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/n8n-io/n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version=${N8N_VERSION}
