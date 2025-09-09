# ===========================
# 1. 构建阶段 (带完整工具链)
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
     python3-dev

WORKDIR /app

# 拉取源码 & 安装依赖
RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn install --production \
  && yarn add puppeteer

# ===========================
# 2. 运行阶段 (轻量化)
# ===========================
FROM --platform=$TARGETPLATFORM node:22-alpine

# 安装运行时需要的依赖
RUN set -ex \
  && apk add --no-cache \
     tini \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel

WORKDIR /app

# 复制构建产物
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

# 在运行环境中安装 Python 依赖（保证版本匹配）
RUN pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt

# 处理 env 配置
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
