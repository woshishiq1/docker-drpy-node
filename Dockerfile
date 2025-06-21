FROM node:22-alpine AS builder

RUN apk add --no-cache python3 build-base

WORKDIR /app

# 只复制 package.json 和 yarn.lock
COPY package.json yarn.lock ./

# 安装运行时依赖（含 puppeteer）
RUN yarn install --production \
  && yarn add puppeteer --production

# 或者先安装所有依赖，再用 --production 清理非生产依赖
# RUN yarn && yarn install --production

FROM node:22-alpine

RUN apk add --no-cache tini \
  && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

# 只复制 node_modules 和 package.json，不复制源码
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]

# 这里假设宿主机源码挂载到 /app/src，所以执行命令要改成：
CMD ["node", "src/index.js"]
