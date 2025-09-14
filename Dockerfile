#
# Dockerfile for drpyS (支持编译 pycryptodome / ujson)
#

FROM node:20-alpine AS builder

ENV LANG=C.UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

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
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && yarn && yarn add puppeteer \
  && sed 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' .env.development > .env \
  && rm -f .env.development \
  && echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > config/env.json

# 建立虚拟环境并安装 Python 依赖
RUN python3 -m venv .venv
ENV PATH="/app/.venv/bin:$PATH"
RUN pip3 install --upgrade pip setuptools wheel \
  && pip3 install -r spider/py/base/requirements.txt

# ----------- 运行镜像阶段 -----------
FROM node:20-alpine

COPY --from=builder /app /app
ENV LANG=C.UTF-8
ENV PYTHONUNBUFFERED=1

# 运行时只需要 python3 + tini（去掉编译工具，减小体积）
RUN set -ex \
  && apk add --update --no-cache \
     python3 tini \
  && rm -rf /tmp/* /var/cache/apk/*

ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /app

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
