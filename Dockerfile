# ==================== 1. 构建阶段 ====================
FROM node:22-alpine AS builder

WORKDIR /app

ENV PUPPETEER_SKIP_DOWNLOAD=1

RUN apk add --no-cache git make python3 py3-pip build-base

# 重新补回拉取仓库代码逻辑
RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

# 清理无用文件 + 文件存在性安全容错防护
RUN rm -rf drpy-node-admin drpy-node-bundle drpy-node-mcp drpy2-quickjs && \
    rm -rf examples install soft .nomedia .vercelignore package-bundle.js package.js package.py vercel.json && \
    ([ -f controllers/admin/terminalController.js ] && \
      sed -i 's|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'bash'"'"'|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'sh'"'"'|' controllers/admin/terminalController.js || true) && \
    ([ -f /app/.plugins.example.js ] && cp /app/.plugins.example.js /app/.plugins.js && rm -f /app/.plugins.example.js || true) && \
    mkdir -p plugins config && \
    ([ -f /app/.env.development ] && cp /app/.env.development /app/.env && rm -f /app/.env.development || true) && \
    ([ -f /app/.env ] && sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env || true) && \
    ([ -f /app/.env ] && sed -i 's|^ENABLE_TERMINAL=0|ENABLE_TERMINAL=1|' /app/.env || true) && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 保留 Puppeteer 25.0.4 + 使用 --ignore-engines 防止打包限制报错
RUN corepack enable && yarn install --ignore-engines && yarn add puppeteer@25.0.4 --ignore-engines

RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# ==================== 2. 运行阶段 ====================
FROM alpine:latest AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

# NODE_OPTIONS="--no-node-snapshot" 用于防止 Node 22 在 ARM32 产生 139 段错误
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
    npm rebuild && \
    python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    apk del .build-deps npm && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

EXPOSE 5757
CMD ["node", "index.js"]
