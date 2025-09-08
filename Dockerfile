# =======================
# 构建阶段
# =======================

# ---------- amd64 builder ----------
FROM node:20-alpine AS builder-amd64
WORKDIR /app
RUN apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ---------- arm64 builder ----------
FROM arm64v8/node:20-alpine AS builder-arm64
WORKDIR /app
RUN apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ---------- armv7 builder ----------
FROM arm32v7/node:20-alpine AS builder-armv7
WORKDIR /app
RUN apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# =======================
# 运行阶段
# =======================

# ---------- amd64 runner ----------
FROM alpine:latest AS runner-amd64
WORKDIR /app
COPY --from=builder-amd64 /tmp/drpys/. /app

# ---------- arm64 runner ----------
FROM arm64v8/alpine:latest AS runner-arm64
WORKDIR /app
COPY --from=builder-arm64 /tmp/drpys/. /app

# ---------- armv7 runner ----------
FROM arm32v7/alpine:latest AS runner-armv7
WORKDIR /app
COPY --from=builder-armv7 /tmp/drpys/. /app

# =======================
# 公共配置
# =======================

# 处理 .env 和 config
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Python3 依赖
RUN apk add --no-cache python3 py3-pip py3-setuptools py3-wheel build-base tini || true

# amd64 / arm64 使用 venv 安装 Python 依赖，armv7 直接系统 pip
RUN if [ "$(uname -m)" != "armv7l" ]; then \
      python3 -m venv /app/.venv && \
      . /app/.venv/bin/activate && \
      pip3 install --upgrade pip setuptools wheel && \
      pip3 install -r /app/spider/py/base/requirements.txt; \
    else \
      pip3 install --upgrade pip setuptools wheel && \
      pip3 install -r /app/spider/py/base/requirements.txt; \
    fi

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
