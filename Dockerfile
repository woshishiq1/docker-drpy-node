# 构建阶段
FROM node:22-alpine AS builder

RUN set -ex \
  && apk add --update --no-cache \
     git \
     build-base \
     python3-dev \
     py3-pip

WORKDIR /app

# 拉取源码 & Node依赖
RUN set -ex \
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn && yarn add puppeteer

# 安装 Python 依赖
RUN pip3 install --no-cache-dir -r spider/py/base/requirements.txt -i https://mirrors.cloud.tencent.com/pypi/simple

# 查看 .env.development 文件是否存在
RUN ls -la /app/.env.development

# 重命名 .env.development 为 .env
RUN mv /app/.env.development /app/.env

# 添加 config/env.json
RUN mkdir -p /app/config && echo '\
{ \
  "ali_token": "", \
  "ali_refresh_token": "", \
  "quark_cookie": "", \
  "uc_cookie": "", \
  "bili_cookie": "", \
  "thread": "10", \
  "enable_dr2": "1", \
  "enable_py": "2", \
  "enable_cat": "2" \
}' > /app/config/env.json


# 运行阶段
FROM node:22-alpine

COPY --from=builder /app /app

RUN set -ex \
  && apk add --update --no-cache \
     tini \
     python3 \
     py3-pip \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

# 确认 .env 文件和 config/env.json 存在
RUN ls -la /app/.env /app/config/env.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
