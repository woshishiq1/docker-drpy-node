# ==================== 1. 构建阶段 ====================
# 锁定 Alpine 3.20 / Node 22 基础镜像，确保编译环境与运行环境版本完全一致
FROM node:22-alpine3.20 AS builder

WORKDIR /app

ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    NODE_OPTIONS="--max-old-space-size=1536"

RUN apk add --no-cache \
    git \
    make python3 py3-pip build-base \
    python3-dev libffi-dev openssl-dev linux-headers

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

RUN corepack enable && yarn && yarn add puppeteer@25.0.4

RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/

# ==================== 2. 运行阶段 ====================
# 使用固定版本的 Alpine（推荐 3.20），彻底规避 C 库/PHP/Python 破坏性变更
FROM alpine:3.20 AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH="/app/.venv/bin:$PATH"

# 统一使用对应 Alpine 版本的稳健软件包
RUN apk add --no-cache \
    tini \
    nodejs \
    php \
    php-cli \
    php-curl \
    php-mbstring \
    php-xml \
    php-pdo \
    php-pdo_mysql \
    php-pdo_sqlite \
    php-openssl \
    php-sqlite3 \
    php-json \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg \
    tzdata && \
    apk add --no-cache --virtual .build-deps \
        gcc g++ musl-dev python3-dev libffi-dev openssl-dev linux-headers && \
    python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
