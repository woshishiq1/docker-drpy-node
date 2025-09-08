# ------------------------
# 构建阶段
# ------------------------
ARG TARGETARCH
# amd64 / arm64 用 Alpine
FROM node:20-alpine AS builder-alpine
# armv7 用 Debian slim
FROM node:20-bullseye-slim AS builder-debian

# 根据架构选择 builder
FROM ${TARGETARCH##*armv7} AS builder

# ---------- 公共步骤 ----------
WORKDIR /app

# 安装基础依赖
# Alpine builder
RUN if [ "$TARGETARCH" != "armv7" ]; then \
      apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base; \
    fi

# Debian builder
RUN if [ "$TARGETARCH" = "armv7" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        git python3 python3-pip python3-venv python3-dev build-essential libffi-dev libssl-dev && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# 克隆源码
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .

# 安装 Node 依赖
RUN yarn && yarn add puppeteer

# 复制临时目录
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ---------- 运行阶段 ----------
FROM alpine:latest AS runner-alpine
FROM debian:bullseye-slim AS runner-debian

FROM ${TARGETARCH##*armv7} AS runner

WORKDIR /app

COPY --from=builder /tmp/drpys/. /app

# 处理 .env 文件
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js（Alpine 和 Debian）
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
