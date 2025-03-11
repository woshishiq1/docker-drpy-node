#
# Dockerfile for drpyS
#

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

FROM node:22-alpine

COPY --from=builder /app /app

RUN set -ex \
  && apk add --update --no-cache \
     tini \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
