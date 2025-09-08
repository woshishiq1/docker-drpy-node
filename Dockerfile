FROM node:20-slim AS builder
# or FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN git clone https://github.com/hjdhnx/drpy-node.git .
RUN yarn && yarn add puppeteer
RUN mkdir -p /tmp/drpys && cp -r /app/. /tmp/drpys/


FROM node:20-slim AS runner
WORKDIR /app
COPY --from=builder /tmp/drpys/. /app

RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    sed -i 's|^VIRTUAL_ENV[[:space:]]*=[[:space:]]*$|VIRTUAL_ENV=/app|' /app/.env && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

# 安装 Python3 + pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install -r /app/spider/py/base/requirements.txt

EXPOSE 5757
CMD ["node", "index.js"]
