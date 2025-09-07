# 构建器阶段
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
# 复制到临时目录
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/

# 运行器阶段
FROM node:22-alpine
RUN set -ex \
  && apk add --update --no-cache \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel \
     libxml2-dev \
     libxslt-dev \
     tini \
  && rm -rf /tmp/* /var/cache/apk/*
WORKDIR /app
COPY --from=builder /tmp/drpys/. /app
# 创建 Python 虚拟环境并安装依赖
RUN set -ex \
  && python3 -m venv /app/.venv \
  && mkdir -p /app/spider/py/base \
  && echo -e "requests\nlxml\npycryptodome\nujson\npyquery\njsonpath\njson5\njinja2\ncachetools\npympler" > /app/spider/py/base/requirements.txt \
  && . /app/.venv/bin/activate \
  && pip3 install --upgrade pip \
  && pip3 install -r /app/spider/py/base/requirements.txt \
  && rm -rf /root/.cache/pip
# 配置 .env 文件
RUN set -ex \
  && mv /app/.env.development /app/.env \
  && sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app/.venv|' /app/.env
# 创建 config/env.json 文件
RUN set -ex \
  && mkdir -p /app/config \
  && echo '{"ali_token": "", "ali_refresh_token": "", "quark_cookie": "", "uc_cookie": "", "bili_cookie": "", "thread": "10", "enable_dr2": "1", "enable_py": "2", "enable_cat": "2"}' > /app/config/env.json
# 确认 .env 文件存在
RUN ls -la /app/.env
EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
