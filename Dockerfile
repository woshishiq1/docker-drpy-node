# ------------------------
# 构建阶段
# ------------------------
ARG TARGETARCH

# ---------- amd64 / arm64 builder ----------
FROM node:20-alpine AS builder-alpine
WORKDIR /app
RUN apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ---------- armv7 builder ----------
FROM arm32v7/node:20-bullseye-slim AS builder-armv7
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    git python3 python3-pip python3-venv python3-dev build-essential libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ---------- 运行阶段 ----------
# 根据 TARGETARCH 选择不同 runner
FROM alpine:latest AS runner-alpine
FROM debian:bullseye-slim AS runner-armv7

# ------------------------
# 选择阶段
# ------------------------
FROM runner-${TARGETARCH} AS runner
WORKDIR /app
COPY --from=builder-${TARGETARCH} /tmp/drpys/. /app

# 处理 .env 和 config
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node
RUN if [ "$TARGETARCH" != "armv7" ]; then \
      apk add --no-cache nodejs tini; \
    else \
      apt-get update && apt-get install -y --no-install-recommends nodejs tini && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# 安装 Python 依赖
RUN if [ "$TARGETARCH" != "armv7" ]; then \
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
