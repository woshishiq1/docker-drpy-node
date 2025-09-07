FROM node:22-alpine AS builder
RUN set -ex \
  && apk add --update --no-cache \
     git \
     build-base \
     python3-dev \
     py3-pip
WORKDIR /app
RUN set -ex \
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn \
  && yarn add puppeteer
# 查看 .env.development 文件是否存在
RUN ls -la /app/.env.development
# 重命名 .env.development 为 .env
RUN mv /app/.env.development /app/.env
FROM node:22-alpine
RUN set -ex \
  && apk add --update --no-cache \
     python3 \
     py3-pip \
     tini \
     libxml2-dev \
     libxslt-dev \
  && rm -rf /tmp/* /var/cache/apk/*
COPY --from=builder /app /app
WORKDIR /app
# 安装 Python 依赖
RUN set -ex \
  && mkdir -p /app/spider/py/base \
  && echo -e "requests\nlxml\npycryptodome\nujson\npyquery\njsonpath\njson5\njinja2\ncachetools\npympler" > /app/spider/py/base/requirements.txt \
  && ls -la /app/spider/py/base
RUN set -ex \
  && pip3 install --break-system-packages -r /app/spider/py/base/requirements.txt -i https://mirrors.cloud.tencent.com/pypi/simple \
  && rm -rf /root/.cache/pip
# 创建 config/env.json 文件
RUN set -ex \
  && mkdir -p /app/config \
  && echo '{"ali_token": "", "ali_refresh_token": "", "quark_cookie": "", "uc_cookie": "", "bili_cookie": "", "thread": "10", "enable_dr2": "1", "enable_py": "2", "enable_cat": "2"}' > /app/config/env.json
# 确认 .env 文件存在
RUN ls -la /app/.env
EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
