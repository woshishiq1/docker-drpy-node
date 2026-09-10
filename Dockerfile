# Dockerfile for drpyS (集成 PHP 环境 + 支持编译 pycryptodome / ujson)

ARG TARGETPLATFORM

# 1. 降级为 node:20-alpine：防止 QEMU 跨平台编译 armv7 时报 Exit Code 132 (Illegal Instruction)
FROM --platform=$TARGETPLATFORM node:20-alpine AS builder

ENV LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1

# 2. 补全 Python C 拓展编译工具（gcc, g++, musl-dev, libffi-dev, openssl-dev），确保 pycryptodome / ujson 等顺利编译
RUN set -ex \
  && apk add --update --no-cache \
     git \
     python3 \
     python3-dev \
     py3-pip \
     py3-wheel \
     gcc \
     g++ \
     make \
     musl-dev \
     libffi-dev \
     openssl-dev

WORKDIR /app
COPY . /app

# 清理无用目录、修正 Alpine 下终端类型、初始化环境变量与配置文件
RUN rm -rf drpy-node-admin drpy-node-bundle drpy-node-mcp drpy2-quickjs && \
    rm -rf examples install soft .nomedia .vercelignore package-bundle.js package.js package.py vercel.json && \
    sed -i 's|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'bash'"'"'|const shell = os.platform() === '"'"'win32'"'"' ? '"'"'powershell.exe'"'"' : '"'"'sh'"'"'|' controllers/admin/terminalController.js && \
    cp /app/.plugins.example.js /app/.plugins.js 2>/dev/null || true && \
    rm -f /app/.plugins.example.js && \
    mkdir -p plugins config && \
    if [ -f /app/.env.development ]; then cp /app/.env.development /app/.env && rm -f /app/.env.development; fi && \
    if [ -f /app/.env ]; then \
      sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env || true; \
      sed -i 's|^ENABLE_TERMINAL=0|ENABLE_TERMINAL=1|' /app/.env || true; \
    fi && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js 依赖
RUN corepack enable && yarn && yarn add puppeteer@25.0.4

# 创建 Python 虚拟环境并编译安装 Python 扩展（包含依赖 C 库的 pycryptodome 和 ujson）
RUN python3 -m venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
RUN pip3 install --upgrade pip setuptools wheel \
  && pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt

# 打包编译产物
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/

# ----------- 运行镜像阶段 -----------
FROM --platform=$TARGETPLATFORM node:20-alpine AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

ENV LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    PATH="/app/.venv/bin:$PATH"

# 运行期只保留运行时所需的 Python3、PHP 8.3 及其扩展组件与 tini
RUN set -ex \
  && apk add --update --no-cache \
     tini \
     python3 \
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
  && ln -sf /usr/bin/php83 /usr/bin/php \
  && rm -rf /tmp/* /var/cache/apk/*

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
