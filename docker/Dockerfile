FROM node:22-bookworm-slim

ARG DSH_SPEC=@deepseek-ai/dsh@latest
ARG GHIDRA_MCP_REF=6f7e7e8988e1efde5dd23372df71fe05c115722e

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git openssh-client python3 python3-venv ripgrep \
    && npm install --global "${DSH_SPEC}" \
    && python3 -m venv /opt/ghidra-mcp-bridge \
    && /opt/ghidra-mcp-bridge/bin/pip install --no-cache-dir "git+https://github.com/bethington/ghidra-mcp.git@${GHIDRA_MCP_REF}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY . /opt/framework
RUN chmod +x /opt/framework/docker/entrypoint.sh /opt/framework/tools/validate.sh \
    && /opt/framework/tools/validate.sh

WORKDIR /workspace
EXPOSE 3080
ENTRYPOINT ["/opt/framework/docker/entrypoint.sh"]
