FROM node:22-alpine AS builder

RUN apk add --no-cache git build-base python3 py3-pip py3-setuptools py3-wheel python3-dev libffi-dev openssl-dev

WORKDIR /app

RUN git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git .

# 安装 Node.js 依赖
RUN npm install -g pm2 && yarn install --production && yarn add puppeteer

# 安装 Python 依赖到临时目录
RUN pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt -t /app/pydeps

# -------------------------
# Runtime
FROM node:22-alpine

RUN apk add --no-cache tini python3 py3-pip py3-setuptools py3-wheel

WORKDIR /app

COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /app/pydeps /usr/local/lib/python3.*/site-packages

RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

EXPOSE 5757
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
