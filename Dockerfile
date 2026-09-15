# ==================== 1. 构建阶段 ====================
FROM node:22-alpine AS builder

WORKDIR /app
COPY . /app

ENV PUPPETEER_SKIP_DOWNLOAD=1

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

RUN apk add --no-cache make python3 py3-pip build-base

# 核心修正：加 --ignore-engines 避开 puppeteer 与 node 版本的报错校验
RUN corepack enable && yarn install --ignore-engines && yarn add puppeteer@25.0.4 --ignore-engines

RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# ==================== 2. 运行阶段 ====================
FROM alpine:latest AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

# 核心修正：针对 Node 22 在 ARM32 上禁用 snapshot 预防段错误
ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    NODE_OPTIONS="--no-node-snapshot" \
    PATH="/app/.venv/bin:$PATH"

RUN apk add --no-cache \
    nodejs \
    npm \
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
    ffmpeg && \
    ln -sf /usr/bin/php83 /usr/bin/php && \
    apk add --no-cache --virtual .build-deps \
        gcc g++ make python3-dev libffi-dev openssl-dev linux-headers && \
    # 原生重新构建 Node C++ 拓展
    npm rebuild && \
    python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    apk del .build-deps npm && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

EXPOSE 5757
CMD ["node", "index.js"]
