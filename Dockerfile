# 声明 TARGETPLATFORM 以支持跨平台构建
ARG TARGETPLATFORM

# ==================== 1. 构建阶段 ====================
FROM node:20-alpine AS builder

WORKDIR /app

# 1. 安装构建与编译依赖（含 git 和 C 拓展编译工具）
RUN apk add --no-cache \
    git make gcc g++ musl-dev build-base \
    python3 python3-dev py3-pip py3-setuptools py3-wheel \
    libffi-dev openssl-dev linux-headers

# 2. 拉取上游项目源码到 /app
RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

# 3. 执行上游项目的清理与配置初始化
RUN rm -rf drpy-node-admin drpy-node-bundle drpy-node-mcp drpy2-quickjs && \
    rm -rf examples install soft .nomedia .vercelignore package-bundle.js package.js package.py vercel.json && \
    ([ -f controllers/admin/terminalController.js ] && sed -i 's|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'bash'"'"'|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'sh'"'"'|' controllers/admin/terminalController.js || true) && \
    cp /app/.plugins.example.js /app/.plugins.js && \
    rm -f /app/.plugins.example.js && \
    mkdir -p plugins && \
    cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    sed -i 's|^ENABLE_TERMINAL=0|ENABLE_TERMINAL=1|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 4. 安装 Node.js 基础依赖（不包含任何 puppeteer）
RUN corepack enable && yarn

# 5. 创建虚拟环境并安装/编译 Python 依赖（含 pycryptodome / ujson）
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt

# 拷贝构建产物到临时文件夹
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# ==================== 2. 运行阶段 ====================
# 直接基于 Node 20 Alpine，天然自带 Node 环境与完整 CA 根证书
FROM node:20-alpine AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

# 1. 安装系统级进程守护工具 tini（已精简 nodejs / ca-certificates / chromium）
RUN apk add --no-cache tini

# 2. 安装 PHP 8.3 环境
RUN apk add --no-cache \
    php83 \
    php83-cli \
    php83-curl \
    php83-mbstring \
    php83-xml \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_sqlite \
    php83-openssl \
    php83-sqlite3 \
    php83-json && \
    ln -sf /usr/bin/php83 /usr/bin/php

# 3. 安装 Python3 运行依赖与 ffmpeg
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
