# 1. 依赖安装阶段
FROM node:22-alpine AS deps

WORKDIR /tmp-src

# 克隆源码到临时目录
RUN apk add --no-cache git && \
    git clone --depth=1 https://github.com/hjdhnx/drpy-node.git .

WORKDIR /app

# 只复制需要的依赖文件
RUN cp /tmp-src/package.json /app/ && \
    cp /tmp-src/yarn.lock /app/

WORKDIR /app

RUN yarn install --production

# 2. 运行阶段
FROM node:22-alpine

RUN apk add --no-cache tini && rm -rf /tmp/* /var/cache/apk/*

WORKDIR /app

# 复制依赖和package.json
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]

# 源码挂载到 /app/src，启动入口调整
CMD ["node", "src/index.js"]
