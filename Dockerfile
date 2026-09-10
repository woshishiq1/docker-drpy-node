# 声明构建参数
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# ==================== 1. 构建阶段 ====================
FROM --platform=$BUILDPLATFORM node:22-alpine AS builder

WORKDIR /app

# 禁止 Puppeteer 下载 + 限制 Node 内存（对 32-bit 很重要）
ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    NODE_OPTIONS="--max-old-space-size=1536"

# 安装构建依赖
RUN apk add --no-cache \
    git make gcc g++ musl-dev build-base \
    python3 python3-dev py3-pip py3-setuptools py3-wheel \
    libffi-dev openssl-dev linux-headers && \
    rm -rf /var/cache/apk/* /tmp/*

# 拉取源码
RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

# 清理与初始化
RUN rm -rf drpy-node-admin drpy-node-bundle drpy-node-mcp drpy2-quickjs && \
    rm -rf examples install soft .nomedia .vercelignore package-bundle.js package.js package.py vercel.json && \
    ([ -f controllers/admin/terminalController.js ] && \
     sed -i 's|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'bash'"'"'|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'sh'"'"'|' controllers/admin/terminalController.js || true) && \
    cp /app/.plugins.example.js /app/.plugins.js && \
    rm -f /app/.plugins.example.js && \
    mkdir -p plugins && \
    cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    sed -i 's|^ENABLE_TERMINAL=0|ENABLE_TERMINAL=1|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node 依赖（跳过 puppeteer 二进制）
RUN corepack enable && \
    yarn && \
    yarn add puppeteer-core@25.0.4   # 改用 core，避免强依赖 chromium

# 创建 venv 并安装 Python 依赖（在目标架构上执行更安全）
# 注意：这里先只装纯 Python 包，真正的 venv 放到 runner 里创建更稳妥
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt || true

# 拷贝产物
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ==================== 2. 运行阶段 ====================
# 关键：使用 alpine 而不是 node:22-alpine，自己装 nodejs
FROM --platform=$TARGETPLATFORM alpine:3.20 AS runner

WORKDIR /app

COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PATH="/app/.venv/bin:$PATH"

# 安装运行时依赖
RUN apk add --no-cache \
    tini \
    nodejs \
    npm \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg \
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
    php83-json \
    ca-certificates \
    tzdata && \
    ln -sf /usr/bin/php83 /usr/bin/php && \
    # 重新创建 venv（保证架构一致）
    python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    if [ -f /app/spider/py/base/requirements.txt ]; then \
        pip install --no-cache-dir -r /app/spider/py/base/requirements.txt; \
    fi && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
