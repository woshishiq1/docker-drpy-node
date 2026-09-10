# Dockerfile for drpyS (支持编译 pycryptodome / ujson 并集成 PHP 环境)

ARG TARGETPLATFORM

FROM --platform=$TARGETPLATFORM node:22-alpine AS builder

ENV LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PUPPETEER_SKIP_DOWNLOAD=1

# 安装构建依赖
RUN set -ex \
  && apk add --update --no-cache \
     git \
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

# 拉源码 + 安装 Node.js 依赖
RUN set -ex \
  && git clone --depth 1 -q https://github.com/woshishiq1/drpys.git . \
  && yarn \
  && if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        yarn add puppeteer ; \
     else \
        yarn add puppeteer-core ; \
     fi \
  && sed 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' .env.development > .env \
  && rm -f .env.development \
  && echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > config/env.json

# 建立虚拟环境并安装 Python 依赖
RUN python3 -m venv .venv
ENV PATH="/app/.venv/bin:$PATH"
RUN pip3 install --upgrade pip setuptools wheel \
  && pip3 install -r spider/py/base/requirements.txt

# ----------- 运行镜像阶段 -----------
FROM --platform=$TARGETPLATFORM node:22-alpine

COPY --from=builder /app /app

ENV LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1

# 运行时依赖：基础工具 + Python + PHP8.3 及完整扩展包
RUN set -ex \
  && apk add --update --no-cache \
     python3 \
     tini \
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

ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /app

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
