# =======================
# 构建阶段
# =======================

FROM node:20-alpine AS builder
WORKDIR /app

# 安装依赖工具
RUN apk add --no-cache git python3 py3-pip py3-setuptools py3-wheel build-base

# 克隆仓库
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .

# 安装 Node 项目依赖
RUN yarn && yarn add puppeteer

# 复制构建好的内容到临时目录
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# =======================
# 运行阶段
# =======================

FROM alpine:latest AS runner
WORKDIR /app

# 复制构建器内容
COPY --from=builder /tmp/drpys/. /app

# 处理 .env 和 config
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Python3 及构建工具
RUN apk add --no-cache python3 py3-pip py3-setuptools py3-wheel build-base tini || true

# 安装 Python 依赖
# amd64 / arm64 使用 venv，armv7 直接系统 pip
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
