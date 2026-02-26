<<<<<<< HEAD
FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app
RUN chown node:node /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

USER node
# Reduce OOM risk on low-memory hosts during dependency installation.
# Docker builds on small VMs may otherwise fail with "Killed" (exit 137).
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

# Optionally install Chromium and Xvfb for browser automation.
# Build with: docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 ...
# Adds ~300MB but eliminates the 60-90s Playwright install on every container start.
# Must run after pnpm install so playwright-core is available in node_modules.
USER root
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      mkdir -p /home/node/.cache/ms-playwright && \
      PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      chown -R node:node /home/node/.cache/ms-playwright && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

USER node
COPY --chown=node:node . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
=======
FROM node:20-bookworm AS build-env

# 这里的思想是基于标准版或者量化官方版再进行改造
# 由于我们是云端打包，可以不直接克隆 openclaw 的完整代码而是找最成熟的源或者只安插件。
# 这里我们假设它是通过 github actions 已经连同源码 clone 下来了。
WORKDIR /opt/openclaw

# NodeJS 模块依赖
# COPY package.json package-lock.json ./
# RUN npm install

# 切换到最终运行环境
FROM node:20-bookworm-slim

# 安装量化分析需要的底层 OS 依赖
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    tmux \
    htop \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 创建并激活 Python 虚拟环境，并安装量化所需的数据分析包
# (Elvis Sun 架构中涉及高级数据处理以及多智能体依赖)
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir \
    pandas \
    numpy \
    requests \
    tushare \
    ccxt \
    scikit-learn

# 全局安装 Node 端的集群控制和管理工具（如 pm2 有助于同时守护多个 Agent）
RUN npm install -g pnpm yarn pm2

WORKDIR /opt/openclaw
# 把构建阶段的二进制或者项目代码复制过来（前提是在 Github Action 里预先下载进上下文了）
COPY . .

# 恢复挂载点
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# 根据 openclaw 的实际启动脚本配置即可，通常是 npm run start 或 node ...
CMD ["npm", "run", "start"]
>>>>>>> ec4107108 (feat: init openclaw stock quant swarm architecture CI/CD workflow)
