# Dockerfile for n8n.io
# Source: https://github.com/n8n-io/n8n/blob/master/docker/images/n8n-base/Dockerfile
# Adjusted for Render.com deployment from source

ARG NODE_VERSION=22
ARG N8N_VERSION=snapshot
ARG LAUNCHER_VERSION=1.1.3
ARG TARGETPLATFORM

# ==============================================================================
# STAGE 1: Builder for Base Dependencies
# ==============================================================================
FROM node:${NODE_VERSION}-alpine AS builder

# Install fonts
RUN \
    apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \;

# Install essential OS dependencies (removed problematic version pins)
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

# Update npm, install full-icu and npm@11.4.2 to fix brace-expansion vulnerability
# Remove npm update after vulnerability is fixed in in node image
RUN npm install -g full-icu@1.5.0 npm@11.4.2

RUN rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn* && \
    apk del apk-tools

# ==============================================================================
# STAGE 2: Build the App (n8n application compilation)
# ==============================================================================
FROM node:${NODE_VERSION} AS build-app

WORKDIR /n8n
COPY . .

# Install dependencies and build the app
RUN corepack enable && \
    corepack prepare pnpm@latest --activate && \
    pnpm install && \
    pnpm build --verbosity 1

# ==============================================================================
# STAGE 3: Task Runner Launcher (for n8n's internal task runners)
# ==============================================================================
FROM alpine:3.22.0 AS launcher-downloader
ARG TARGETPLATFORM
ARG LAUNCHER_VERSION

RUN set -e; \
    case "$TARGETPLATFORM" in \
        "linux/amd64") ARCH_NAME="amd64" ;; \
        "linux/arm64") ARCH_NAME="arm64" ;; \
        *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac; \
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

# Use compiled code from the build-app stage
COPY --from=build-app /n8n /usr/local/lib/node_modules/n8n
COPY --from=launcher-downloader /launcher-bin/* /usr/local/bin/
# Copy from the original build context root (where the repository was cloned)
COPY ./docker/images/n8n/docker-entrypoint.sh /
COPY ./docker/images/n8n/n8n-task-runners.json /etc/n8n-task-runners.json

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
