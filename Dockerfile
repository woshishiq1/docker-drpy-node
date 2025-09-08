FROM alpine:3.19 AS runner

WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

# 配置环境文件
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Node.js + Python3 + 构建依赖
RUN apk add --no-cache \
    nodejs \
    python3 \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    build-base \
    linux-headers \
    musl-dev \
    python3-dev \
    libffi-dev \
    openssl-dev \
    zlib-dev \
    jpeg-dev \
    freetype-dev

# 安装 Python requirements
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install -r /app/spider/py/base/requirements.txt

EXPOSE 5757
CMD ["node", "index.js"]
