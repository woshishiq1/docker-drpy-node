# ------------------------
# 构建阶段
# ------------------------
FROM node:20-alpine AS builder

# 安装基础构建依赖
RUN apk add --no-cache git

# Git 配置
RUN git config --global http.version HTTP/1.1

WORKDIR /app

# 克隆仓库
RUN git clone https://github.com/hjdhnx/drpy-node.git .

# 安装 Node 依赖和 Puppeteer
RUN yarn && yarn add puppeteer

# 复制临时目录，为运行阶段准备
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# ------------------------
# 运行阶段
# ------------------------
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

# 安装 Node.js 运行时
RUN apk add --no-cache nodejs

# 安装 Python 基础运行环境
RUN apk add --no-cache python3 py3-pip py3-setuptools py3-wheel

# 根据架构安装 Python 依赖
RUN if [ "$TARGETARCH" = "armv7" ]; then \
      # armv7 需要临时编译依赖
      apk add --no-cache --virtual .build-deps \
        gcc g++ make musl-dev python3-dev libffi-dev openssl-dev && \
      pip3 install --upgrade pip setuptools wheel && \
      pip3 install -r /app/spider/py/base/requirements.txt && \
      apk del .build-deps; \
    else \
      # amd64 / arm64 使用 venv
      python3 -m venv /app/.venv && \
      . /app/.venv/bin/activate && \
      pip3 install --upgrade pip setuptools wheel && \
      pip3 install -r /app/spider/py/base/requirements.txt; \
    fi

# 暴露端口
EXPOSE 5757

# 启动命令
CMD ["node", "index.js"]
