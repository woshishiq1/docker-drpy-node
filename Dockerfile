# ------------------------
# 构建阶段
# ------------------------
FROM node:22-alpine AS builder

RUN set -ex \
  && apk add --no-cache \
     git \
     build-base \
     python3-dev \
     py3-pip \
     py3-setuptools \
     py3-wheel

WORKDIR /app

# 克隆源码 + 安装 Node 依赖
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn \
  && yarn add puppeteer

# 处理 .env 文件
RUN mv /app/.env.development /app/.env

# 安装 Python 依赖（直接系统级安装，不使用 venv）
RUN pip3 install --upgrade pip setuptools wheel \
  && pip3 install -r /app/spider/py/base/requirements.txt

# ------------------------
# 运行阶段
# ------------------------
FROM node:22-alpine AS runner

# 安装 tini 和 python3 基础运行时
RUN apk add --no-cache tini python3 py3-pip

WORKDIR /app

# 复制构建产物
COPY --from=builder /app /app

# 写入默认 config/env.json
RUN echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
