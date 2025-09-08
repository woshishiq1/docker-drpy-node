# 构建器阶段
# 使用 node:20-alpine (17 < version < 23) 作为基础镜像
FROM node:20-alpine AS builder

# 安装 git
RUN apk add --no-cache git

# 如果您需要配置 git 以使用特定的 HTTP 版本，请确保这是出于必要和安全考虑
RUN git config --global http.version HTTP/1.1

# 创建一个工作目录
WORKDIR /app

# 克隆 GitHub 仓库到工作目录
RUN git clone https://github.com/hjdhnx/drpy-node.git .

# 安装项目依赖项和 puppeteer
RUN yarn && yarn add puppeteer

# 复制工作目录中的所有文件到一个临时目录中
RUN mkdir -p /tmp/drpys && \
    cp -r /app/. /tmp/drpys/


# 运行器阶段
# 使用 alpine:3.19+ (避免老版本 alpine 缺失包)
FROM alpine:3.19 AS runner

# 创建一个工作目录
WORKDIR /app

# 复制构建器阶段准备好的文件
COPY --from=builder /tmp/drpys/. /app

# 配置环境文件
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js 运行时
RUN apk add --no-cache nodejs

# 安装 Python3 和 pip（系统全局环境，不用 venv）
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    && pip3 install --upgrade pip setuptools wheel \
    && pip3 install -r /app/spider/py/base/requirements.txt

# 暴露应用程序端口
EXPOSE 5757

# 启动命令
CMD ["node", "index.js"]
