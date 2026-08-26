FROM node:22-bookworm-slim AS dsh-builder

ARG DSH_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness.git
ARG DSH_SOURCE_REF=b150a551b8d465e31e418e1b2eaf5e79bbb7d28e

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates git python3 make g++ \
    && npm install --global pnpm@11.7.0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /opt/deepseek-harness \
    && git -C /opt/deepseek-harness init \
    && git -C /opt/deepseek-harness remote add origin "${DSH_SOURCE_URL}" \
    && git -C /opt/deepseek-harness fetch --depth 1 origin "${DSH_SOURCE_REF}" \
    && git -C /opt/deepseek-harness checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/deepseek-harness rev-parse HEAD)" = "${DSH_SOURCE_REF}"

RUN pnpm --dir /opt/deepseek-harness install --frozen-lockfile \
    && pnpm --dir /opt/deepseek-harness run build \
    && rm -rf /opt/deepseek-harness/.git

FROM node:22-bookworm-slim

ARG GHIDRA_MCP_REF=6f7e7e8988e1efde5dd23372df71fe05c115722e
ARG DSH_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness.git
ARG DSH_SOURCE_REF=b150a551b8d465e31e418e1b2eaf5e79bbb7d28e

LABEL org.opencontainers.image.source="${DSH_SOURCE_URL}" \
      org.opencontainers.image.revision="${DSH_SOURCE_REF}"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git openssh-client python3 python3-venv ripgrep \
    && npm install --global pnpm@11.7.0 \
    && python3 -m venv /opt/ghidra-mcp-bridge \
    && /opt/ghidra-mcp-bridge/bin/pip install --no-cache-dir "git+https://github.com/bethington/ghidra-mcp.git@${GHIDRA_MCP_REF}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=dsh-builder /opt/deepseek-harness /opt/deepseek-harness
COPY . /opt/framework
RUN chmod +x /opt/framework/docker/entrypoint.sh /opt/framework/tools/validate.sh \
    && /opt/framework/tools/validate.sh

WORKDIR /workspace
EXPOSE 3080
ENTRYPOINT ["/opt/framework/docker/entrypoint.sh"]
