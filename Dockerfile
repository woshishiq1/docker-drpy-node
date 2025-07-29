FROM node:22-alpine AS builder

RUN set -ex \
  && apk add --update --no-cache \
     git \
     build-base \
     python3-dev

WORKDIR /app

RUN set -ex \
  && git clone --depth 1 -q https://github.com/hjdhnx/drpy-node.git . \
  && npm install -g pm2 \
  && yarn && yarn add puppeteer

# 查看 .env.development 文件是否存在
RUN ls -la /app/.env.development

# 重命名 .env.development 为 .env
RUN mv /app/.env.development /app/.env

FROM node:22-alpine

COPY --from=builder /app /app

RUN set -ex \
  && apk add --update --no-cache \
     tini \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

# 确认 .env 文件存在
RUN ls -la /app/.env

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
