# 构建阶段
FROM node:22-alpine AS builder

RUN set -ex \
  && apk add --update --no-cache \
     git \
     build-base \
     python3-dev

WORKDIR /app

# 克隆源码并安装依赖
RUN set -ex \
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn \
  && yarn add puppeteer

# 确认并处理环境文件
RUN ls -la /app/.env.development \
  && mv /app/.env.development /app/.env

# 运行阶段
FROM node:22-alpine

WORKDIR /app

# 复制构建产物
COPY --from=builder /app /app

# 安装 tini 以及运行所需依赖
RUN set -ex \
  && apk add --no-cache tini python3 py3-pip py3-setuptools py3-wheel \
  && rm -rf /tmp/* /var/cache/apk/*

# Python 虚拟环境 + requirements 安装
RUN python3 -m venv /app/.venv && \
    . /app/.venv/bin/activate && \
    pip3 install -r /app/spider/py/base/requirements.txt

# 修复 .env 里的 VIRTUAL_ENV 路径（如果为空）
RUN sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env

# 写入默认 config/env.json
RUN echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 确认最终 .env 文件存在
RUN ls -la /app/.env

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
