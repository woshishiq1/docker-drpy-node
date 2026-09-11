ARG TARGETPLATFORM
ARG BUILDPLATFORM

# ==================== 1. 构建阶段（只准备源码，不编译 native） ====================
FROM --platform=$BUILDPLATFORM node:22-alpine AS builder

WORKDIR /app

ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    NODE_OPTIONS="--max-old-space-size=1536"

RUN apk add --no-cache git

RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

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

# 只装 JS 依赖，不跑 install 脚本（避免在 x86 上编 native）
RUN corepack enable && \
    yarn --ignore-scripts && \
    yarn add puppeteer@25.0.4 --ignore-scripts

RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/ && \
    # 去掉可能残留的错误架构 native，到 runner 再装
    rm -rf /tmp/drpys/node_modules

# ==================== 2. 运行阶段（在目标架构 armv7 上装依赖） ====================
FROM alpine:3.20 AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PATH="/app/.venv/bin:$PATH"

RUN apk add --no-cache \
    tini \
    nodejs \
    npm \
    yarn \
    # PHP（hi3798 上可能仍 segfault，不需要可整段删掉）
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
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg \
    tzdata && \
    ln -sf /usr/bin/php83 /usr/bin/php && \
    # 编译 native / pip 需要的工具（装完再删）
    apk add --no-cache --virtual .build-deps \
        python3 make g++ gcc musl-dev python3-dev libffi-dev openssl-dev && \
    # 在 armv7 上安装 Node 依赖（关键）
    corepack enable && \
    yarn && \
    yarn add puppeteer@25.0.4 && \
    # Python venv
    python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache /usr/local/share/.cache

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
