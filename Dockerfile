# 1. 依赖安装阶段
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn install --production

# 2. 运行阶段
FROM node:22-alpine

RUN apk add --no-cache tini \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]

# 源码目录挂载在 /app/src，运行入口改为 /app/src/index.js
CMD ["node", "src/index.js"]
