# syntax=docker/dockerfile:1
FROM ghidra_source AS source

FROM eclipse-temurin:21-jdk-jammy AS builder
ARG GHIDRA_VERSION=12.1.2
ARG GHIDRA_DATE=20260605
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends maven unzip wget && rm -rf /var/lib/apt/lists/*
WORKDIR /opt
RUN wget -q "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" -O ghidra.zip \
    && unzip -q ghidra.zip && rm ghidra.zip && mv ghidra_* ghidra
RUN set -eu; for spec in \
      Generic:Framework/Generic \
      SoftwareModeling:Framework/SoftwareModeling \
      Project:Framework/Project \
      Docking:Framework/Docking \
      Utility:Framework/Utility \
      Gui:Framework/Gui \
      FileSystem:Framework/FileSystem \
      Help:Framework/Help \
      Base:Features/Base \
      Decompiler:Features/Decompiler \
      DB:Framework/DB \
      Emulation:Framework/Emulation \
      Debugger-api:Debug/Debugger-api \
      Framework-TraceModeling:Debug/Framework-TraceModeling \
      Debugger-rmi-trace:Debug/Debugger-rmi-trace; do \
        artifact=${spec%%:*}; path=${spec#*:}; \
        mvn -q install:install-file -Dfile="/opt/ghidra/Ghidra/$path/lib/$artifact.jar" \
          -DgroupId=ghidra -DartifactId="$artifact" -Dversion="$GHIDRA_VERSION" -Dpackaging=jar; \
      done
WORKDIR /build
COPY --from=source /pom.xml .
COPY --from=source /src ./src
COPY --from=source /lib ./lib
RUN mvn clean package -P headless -DskipTests -q

FROM eclipse-temurin:21-jdk-jammy
ENV GHIDRA_HOME=/opt/ghidra GHIDRA_MCP_PORT=8089 JAVA_OPTS="-Xmx4g -XX:+UseG1GC" HOME=/home/ghidra
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl unzip && rm -rf /var/lib/apt/lists/*
COPY --from=builder /opt/ghidra /opt/ghidra
RUN set -eu; extension=$(find /opt/ghidra/Extensions/Ghidra -maxdepth 1 -name '*_Jython.zip' -print -quit); \
    test -n "$extension"; mkdir -p /opt/ghidra/Ghidra/Extensions; unzip -q "$extension" -d /opt/ghidra/Ghidra/Extensions
RUN mkdir -p /app /data /projects
COPY --from=builder /build/target/GhidraMCP-*.jar /app/GhidraMCP.jar
COPY --from=source /docker/entrypoint.sh /app/entrypoint.sh
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh \
    && groupadd --gid 10001 ghidra && useradd --uid 10001 --gid 10001 --create-home --home-dir /home/ghidra ghidra \
    && chown -R ghidra:ghidra /app /data /projects /home/ghidra
USER ghidra
EXPOSE 8089
VOLUME ["/data", "/projects"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD curl -f http://localhost:${GHIDRA_MCP_PORT}/check_connection || exit 1
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--port", "8089"]
