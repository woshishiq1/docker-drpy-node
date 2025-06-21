# 1. 依赖安装阶段
FROM node:22-alpine AS deps

WORKDIR /tmp-src

RUN apk add --no-cache git && \
    git clone --depth=1 https://github.com/hjdhnx/drpy-node.git .

WORKDIR /app

# 只复制package.json，因为yarn.lock不存在
RUN cp /tmp-src/package.json /app/

WORKDIR /app

RUN yarn install --production

# 2. 运行阶段
FROM node:22-alpine

RUN apk add --no-cache tini && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["node", "index.js"]
