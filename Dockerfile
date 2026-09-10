# 声明 TARGETPLATFORM 以支持多架构构建 (配合 docker buildx)
ARG TARGETPLATFORM

# 构建阶段
FROM --platform=$TARGETPLATFORM node:22-alpine AS builder

# 关键：跳过 Puppeteer 自动下载二进制包（解决 ARMv7 无默认 Chromium 的问题）
ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /app
COPY . /app

# 执行原上游的文件清理与配置初始化
RUN rm -rf drpy-node-admin drpy-node-bundle drpy-node-mcp drpy2-quickjs && \
    rm -rf examples install soft .nomedia .vercelignore package-bundle.js package.js package.py vercel.json && \
    sed -i 's|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'bash'"'"'|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'sh'"'"'|' controllers/admin/terminalController.js && \
    cp /app/.plugins.example.js /app/.plugins.js && \
    rm -f /app/.plugins.example.js && \
    mkdir -p plugins && \
    cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    sed -i 's|^ENABLE_TERMINAL=0|ENABLE_TERMINAL=1|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 1. 安装编译 pycryptodome / ujson / cffi 等 Python C拓展必须的标头文件和编译器
RUN apk add --no-cache \
    make gcc g++ musl-dev build-base \
    python3 python3-dev py3-pip py3-setuptools py3-wheel \
    libffi-dev openssl-dev linux-headers

# 2. 安装 Node.js 依赖
RUN corepack enable && yarn && yarn add puppeteer@25.0.4

# 3. 创建虚拟环境并预先编译/安装 Python 依赖
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt

# 拷贝到临时目录准备交给运行阶段
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# 运行器阶段
FROM --platform=$TARGETPLATFORM alpine:latest AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    PATH="/app/.venv/bin:$PATH"

# 1. 安装 Node.js 和系统的 Chromium（提供 ARMv7 上的浏览器支持）
RUN apk add --no-cache nodejs chromium nss freetype harfbuzz ca-certificates ttf-freefont

# 2. 安装上游依赖的 PHP 8.3 扩展环境
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

# 3. 安装 Python3 运行环境与 ffmpeg
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg

EXPOSE 5757
CMD ["node", "index.js"]
