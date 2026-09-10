# 声明 TARGETPLATFORM 以支持跨平台构建 (如 armv7, arm64, amd64)
ARG TARGETPLATFORM

# ==================== 1. 构建阶段 ====================
FROM node:22-alpine AS builder

WORKDIR /app

# 设置构建期环境变量：跳过 Puppeteer 自动下载 Chromium
ENV PUPPETEER_SKIP_DOWNLOAD=1

# 1. 安装构建与编译依赖（含 ARMv7 架构下编译 Python C 扩展所需的工具）
RUN apk add --no-cache \
    git make gcc g++ musl-dev build-base \
    python3 python3-dev py3-pip py3-setuptools py3-wheel \
    libffi-dev openssl-dev linux-headers && \
    rm -rf /var/cache/apk/* /tmp/*

# 2. 拉取 upstream 源码到 /app
RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

# 3. 执行项目清理与初始化配置（上游逻辑）
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

# 4. 安装 Node.js 依赖与 Puppeteer（上游逻辑，配合 ENV 自动跳过 Chromium 下载）
RUN corepack enable && yarn && yarn add puppeteer@25.0.4

# 5. 创建虚拟环境并预先安装 Python 依赖（支持 ARMv7 预编译）
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    rm -rf /tmp/* /root/.cache

# 6. 拷贝构建产物到临时目录
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# ==================== 2. 运行阶段 ====================
FROM alpine:latest AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PATH="/app/.venv/bin:$PATH"

# 1. 安装 Node.js 运行环境
RUN apk add --no-cache nodejs && \
    rm -rf /var/cache/apk/* /tmp/*

# 2. 安装 PHP 8.3 环境（上游逻辑）
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
    ln -sf /usr/bin/php83 /usr/bin/php && \
    rm -rf /var/cache/apk/* /tmp/*

# 3. 安装 Python3 运行依赖、ffmpeg 以及系统守护工具 tini
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg \
    tini && \
    rm -rf /var/cache/apk/* /tmp/*

# 4. 激活并安装运行期的 Python 依赖（上游原有的二次保底逻辑）
RUN . /app/.venv/bin/activate && \
    pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    rm -rf /tmp/* /root/.cache

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
