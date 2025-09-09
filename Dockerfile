# ===========================
# 2. 运行阶段 (无工具链)
# ===========================
FROM node:22-alpine

RUN set -ex \
  && apk add --no-cache \
     tini \
     python3 \
     py3-pip \
     py3-setuptools \
     py3-wheel

WORKDIR /app

# 复制构建产物
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

# ⚡ 在 runtime 里直接安装 Python 依赖（保证和实际 Python 版本一致）
RUN pip3 install --no-cache-dir -r /app/spider/py/base/requirements.txt

# 处理 env 配置
RUN cp /app/.env.development /app/.env && \
    rm -f /app/.env.development && \
    echo '{"ali_token":"","ali_refresh_token":"","quark_cookie":"","uc_cookie":"","bili_cookie":"","thread":"10","enable_dr2":"1","enable_py":"2"}' > /app/config/env.json

EXPOSE 5757

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]
