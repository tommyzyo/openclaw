FROM node:22-bookworm AS build-env

# 这里的思想是基于标准版或者量化官方版再进行改造
# 由于我们是云端打包，可以不直接克隆 openclaw 的完整代码而是找最成熟的源或者只安插件。
# 这里我们假设它是通过 github actions 已经连同源码 clone 下来了。
WORKDIR /opt/openclaw

# NodeJS 模块依赖
# COPY package.json package-lock.json ./
# RUN npm install

# 切换到最终运行环境
FROM node:22-bookworm-slim

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
