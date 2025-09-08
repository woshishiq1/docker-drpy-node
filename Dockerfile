# ===========================
# 1. 构建阶段
# ===========================
FROM node:22-alpine AS builder

RUN set -ex \
  && apk add --update --no-cache \
     git \
     build-base \
     python3-dev

WORKDIR /app

# 拉取源码 & 安装依赖
RUN set -ex \
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn \
  && yarn add puppeteer

# ===========================
# 2. 运行阶段
# ===========================
FROM node:22-alpine

# 拷贝构建产物
COPY --from=builder /app /app

RUN set -ex \
  && apk add --update --no-cache \
     tini \
     nodejs \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

# 处理 env 配置
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# Python 虚拟环境 & 安装依赖
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
