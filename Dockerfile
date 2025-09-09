# ===========================
# 1. 构建阶段 (builder)
# ===========================
FROM --platform=$BUILDPLATFORM node:22-alpine AS builder

# 安装构建依赖
RUN set -ex \
  && apk add --no-cache \
     git \
     build-base \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel \
     python3-dev \
     libffi-dev \
     openssl-dev

WORKDIR /app

# 拉取源码 & 安装 Node.js 依赖
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn install --production \
  && yarn add puppeteer

# 安装 Python 依赖到系统路径
RUN pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt

# ===========================
# 2. 运行阶段 (runtime)
# ===========================
FROM --platform=$TARGETPLATFORM node:22-alpine AS runner

# 安装运行依赖
RUN set -ex \
  && apk add --no-cache \
     tini \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel

WORKDIR /app

# 拷贝源码与 Node 模块
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

# 配置 env
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
