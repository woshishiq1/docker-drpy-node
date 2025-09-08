# 构建器阶段
FROM node:20-alpine AS builder

# 安装git
RUN apk add --no-cache git

# 如果需要配置git以使用特定HTTP版本
RUN git config --global http.version HTTP/1.1

WORKDIR /app

# 克隆仓库
RUN git clone https://github.com/hjdhnx/drpy-node.git .

# 安装Node依赖和puppeteer
RUN yarn && yarn add puppeteer

# 复制临时目录
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# 运行器阶段
FROM alpine:latest AS runner

ARG TARGETARCH

WORKDIR /app

# 复制构建产物
COPY --from=builder /tmp/drpys/. /app

# 处理 .env 文件
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js
RUN apk add --no-cache nodejs

# 安装 Python 基础依赖
RUN apk add --no-cache python3 py3-pip py3-setuptools py3-wheel

# 区分架构安装 Python 依赖
# amd64 / arm64: 使用 venv
# armv7: 直接系统安装（不走 venv，避免报错）
RUN if [ "$TARGETARCH" = "armv7" ]; then \
      pip3 install --upgrade pip setuptools wheel && \
      pip3 install -r /app/spider/py/base/requirements.txt; \
    else \
      python3 -m venv /app/.venv && \
      . /app/.venv/bin/activate && \
      pip3 install -r /app/spider/py/base/requirements.txt; \
    fi

EXPOSE 5757

CMD ["node", "index.js"]
