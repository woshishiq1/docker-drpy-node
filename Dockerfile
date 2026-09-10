# 声明 TARGETPLATFORM 以支持跨平台构建 (如 armv7, arm64, amd64)
ARG TARGETPLATFORM

# ==================== 1. 构建阶段 ====================
# 使用 node:20-alpine 防范 Node 22 在 ARMv7 上的 Illegal instruction (exit 132) 崩溃
FROM node:20-alpine AS builder

WORKDIR /app

# 1. 关键环境变量：禁止 Puppeteer 在构建阶段去下载不支持 ARMv7 的 Chromium
ENV PUPPETEER_SKIP_DOWNLOAD=1

# 2. 安装构建与编译依赖（含 ARMv7 编译 C/Python 扩展所需工具）
RUN apk add --no-cache \
    git make gcc g++ musl-dev build-base \
    python3 python3-dev py3-pip py3-setuptools py3-wheel \
    libffi-dev openssl-dev linux-headers && \
    rm -rf /var/cache/apk/* /tmp/*

# 3. 异库拉取上游项目源码到 /app
RUN git clone --depth 1 -q https://github.com/woshishiq1/drpys.git .

# 4. 执行清理与初始化配置
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

# 5. 安装基础 Node 依赖并强制安装 puppeteer@25.0.4（忽略 Node 版本限制，防止编译卡死）
RUN corepack enable && yarn && npm install puppeteer@25.0.4 --ignore-engines --legacy-peer-deps

# 6. 创建虚拟环境并预先安装 Python 依赖（支持 ARMv7 预编译）
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/spider/py/base/requirements.txt && \
    rm -rf /tmp/* /root/.cache

# 7. 拷贝构建产物到临时目录
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# ==================== 2. 运行阶段 ====================
FROM node:20-alpine AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

# 环境变量：指定跳过下载 + 显式指向 Alpine 系统的 Chromium
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    PATH="/app/.venv/bin:$PATH"

# 1. 安装系统级守护工具 tini 与针对 ARMv7 适配好的 Alpine 官方 Chromium
RUN apk add --no-cache \
    tini \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont && \
    rm -rf /var/cache/apk/* /tmp/*

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
    ln -sf /usr/bin/php83 /usr/bin/php && \
    rm -rf /var/cache/apk/* /tmp/*

# 3. 安装 Python3 运行依赖与 ffmpeg
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    ffmpeg && \
    rm -rf /var/cache/apk/* /tmp/*

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
