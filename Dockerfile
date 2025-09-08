# =======================
# 构建器阶段
# =======================
FROM node:20-alpine AS builder

# 安装 git
RUN apk add --no-cache git

# 强制 HTTP/1.1（可选）
RUN git config --global http.version HTTP/1.1

WORKDIR /app

# 克隆仓库
RUN git clone https://github.com/hjdhnx/drpy-node.git .

# 安装依赖（含 puppeteer）
RUN yarn && yarn add puppeteer

# 拷贝文件到临时目录
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/


# =======================
# 运行器阶段
# =======================
FROM alpine:latest AS runner

WORKDIR /app

# 拷贝构建产物
COPY --from=builder /tmp/drpys/. /app

# .env 配置
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js 运行时
RUN apk add --no-cache nodejs

# 安装 Python3 + venv 支持
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    python3-venv

# 创建虚拟环境并安装依赖
RUN python3 -m venv /app/.venv && \
    /app/.venv/bin/pip install --upgrade pip setuptools wheel && \
    /app/.venv/bin/pip install -r /app/spider/py/base/requirements.txt

EXPOSE 5757

CMD ["node", "index.js"]
