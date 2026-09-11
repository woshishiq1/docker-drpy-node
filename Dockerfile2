# ==================== 1. 构建阶段 ====================
FROM node:22-alpine AS builder

WORKDIR /app

ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    NODE_OPTIONS="--max-old-space-size=1536"

# 安装编译原生 node 模块所需的系统依赖
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

# 针对目标架构编译安装 Node.js 依赖
RUN corepack enable && yarn && yarn add puppeteer@25.0.4

RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/

# ==================== 2. 运行阶段 ====================
FROM alpine:latest AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PATH="/app/.venv/bin:$PATH"

# 1. 使用 Alpine 标准 PHP 软件包名（无需手动 ln -sf 软链接）
# 2. 安装 Python 依赖所需的 C 编译支持
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
