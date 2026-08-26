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

FROM node:22-bookworm-slim AS customizations-builder

ARG DSH_PLUGINS_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness-plugins.git
ARG DSH_PLUGINS_SOURCE_REF=530b595efdf787c97474c4d7eee8ee8caa96d6f2
ARG DSH_SKILLS_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness-skills.git
ARG DSH_SKILLS_SOURCE_REF=ae9880bfc478b30a48e5855385e08ea05bcd5108

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates git \
    && npm install --global pnpm@11.7.0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /opt/deepseek-harness-plugins \
    && git -C /opt/deepseek-harness-plugins init \
    && git -C /opt/deepseek-harness-plugins remote add origin "${DSH_PLUGINS_SOURCE_URL}" \
    && git -C /opt/deepseek-harness-plugins fetch --depth 1 origin "${DSH_PLUGINS_SOURCE_REF}" \
    && git -C /opt/deepseek-harness-plugins checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/deepseek-harness-plugins rev-parse HEAD)" = "${DSH_PLUGINS_SOURCE_REF}" \
    && mkdir /opt/deepseek-harness-skills \
    && git -C /opt/deepseek-harness-skills init \
    && git -C /opt/deepseek-harness-skills remote add origin "${DSH_SKILLS_SOURCE_URL}" \
    && git -C /opt/deepseek-harness-skills fetch --depth 1 origin "${DSH_SKILLS_SOURCE_REF}" \
    && git -C /opt/deepseek-harness-skills checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/deepseek-harness-skills rev-parse HEAD)" = "${DSH_SKILLS_SOURCE_REF}"

RUN pnpm --dir /opt/deepseek-harness-plugins/skill-mcp-manager install --frozen-lockfile \
    && pnpm --dir /opt/deepseek-harness-plugins/skill-mcp-manager run build \
    && pnpm --dir /opt/deepseek-harness-plugins/system-prompt-editor install --frozen-lockfile \
    && pnpm --dir /opt/deepseek-harness-plugins/system-prompt-editor run build \
    && pnpm --dir /opt/deepseek-harness-plugins/web-search-searxng install --frozen-lockfile \
    && pnpm --dir /opt/deepseek-harness-plugins/web-search-searxng run build \
    && rm -rf /opt/deepseek-harness-plugins/.git /opt/deepseek-harness-skills/.git

FROM eclipse-temurin:25-jdk-jammy AS java-runtime

FROM node:22-bookworm-slim

ARG GHIDRA_MCP_REF=6f7e7e8988e1efde5dd23372df71fe05c115722e
ARG JD_MCP_DUO_VERSION=v4.2.5.4
ARG JD_MCP_DUO_SHA256=a68762013ca9375b72d7021a5732dba3743de67f7c25b1834f3579f00672ff3f
ARG WIRESHARK_MCP_REF=2a8c009fb38723a9212e47d6156cc8a6b2f624c0
ARG DSH_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness.git
ARG DSH_SOURCE_REF=b150a551b8d465e31e418e1b2eaf5e79bbb7d28e
ARG DSH_PLUGINS_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness-plugins.git
ARG DSH_PLUGINS_SOURCE_REF=530b595efdf787c97474c4d7eee8ee8caa96d6f2
ARG DSH_SKILLS_SOURCE_URL=https://github.com/n0pe-sled/deepseek-harness-skills.git
ARG DSH_SKILLS_SOURCE_REF=ae9880bfc478b30a48e5855385e08ea05bcd5108

LABEL org.opencontainers.image.source="${DSH_SOURCE_URL}" \
      org.opencontainers.image.revision="${DSH_SOURCE_REF}" \
      org.deepseek-harness.plugins.source="${DSH_PLUGINS_SOURCE_URL}" \
      org.deepseek-harness.plugins.revision="${DSH_PLUGINS_SOURCE_REF}" \
      org.deepseek-harness.skills.source="${DSH_SKILLS_SOURCE_URL}" \
      org.deepseek-harness.skills.revision="${DSH_SKILLS_SOURCE_REF}"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git iproute2 iptables openresolv openssh-client python3 python3-venv ripgrep socat sshpass tshark wireguard-tools \
    && npm install --global pnpm@11.7.0 \
    && python3 -m venv /opt/ghidra-mcp-bridge \
    && /opt/ghidra-mcp-bridge/bin/pip install --no-cache-dir "git+https://github.com/bethington/ghidra-mcp.git@${GHIDRA_MCP_REF}" \
    && python3 -m venv /opt/wireshark-mcp \
    && /opt/wireshark-mcp/bin/pip install --no-cache-dir "git+https://github.com/bx33661/Wireshark-MCP.git@${WIRESHARK_MCP_REF}" \
    && python3 -m venv /opt/windows-remote \
    && /opt/windows-remote/bin/pip install --no-cache-dir "pywinrm==0.5.0" \
    && mkdir -p /opt/jd-mcp-duo \
    && curl -fsSL "https://github.com/AgeloVito/jd-mcp-duo/releases/download/${JD_MCP_DUO_VERSION}/jd-mcp-duo.jar" -o /opt/jd-mcp-duo/jd-mcp-duo.jar \
    && echo "${JD_MCP_DUO_SHA256}  /opt/jd-mcp-duo/jd-mcp-duo.jar" | sha256sum -c - \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=dsh-builder /opt/deepseek-harness /opt/deepseek-harness
COPY --from=customizations-builder /opt/deepseek-harness-plugins /opt/deepseek-harness-plugins
COPY --from=customizations-builder /opt/deepseek-harness-skills /opt/deepseek-harness-skills
COPY --from=java-runtime /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:$PATH
COPY . /opt/framework
RUN chmod +x /opt/framework/docker/entrypoint.sh /opt/framework/docker/ludus-wireguard.py /opt/framework/tools/ludus-ssh /opt/framework/tools/ludus-winrm.py /opt/framework/tools/validate.sh \
    && /opt/framework/tools/validate.sh \
    && javap -version

WORKDIR /workspace
EXPOSE 3080
ENTRYPOINT ["/opt/framework/docker/entrypoint.sh"]
