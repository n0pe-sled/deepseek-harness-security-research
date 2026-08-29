# syntax=docker/dockerfile:1
# Containerized headless Burp Suite Professional.
# Phase 1 (feature/burp-container): isolated, unprivileged, fail-closed.
#
# Build-time inputs:
#   BURP_VERSION   - exact Burp Professional version (required)
#   BURP_SHA256    - sha256 of the distribution artifact (required)
#   BURP_DIST_URL  - private, authenticated URL for the artifact. When empty,
#                    the build copies burp/dist/<BURP_JAR_NAME> from the build
#                    context. Never commit the artifact or a license to git.
#   BURP_JAR_NAME  - target artifact name (default burpsuite_pro.jar)
#
# The artifact may be the runnable jar or a .tar.gz/.zip containing
# burpsuite_pro.jar. The .sh install4j installer is not supported directly;
# extract its jar or host a tarball instead.

ARG JAVA_TAG=21-jre-jammy
FROM eclipse-temurin:${JAVA_TAG}

ARG BURP_VERSION
ARG BURP_SHA256
ARG BURP_DIST_URL
ARG BURP_JAR_NAME=burpsuite_pro.jar
ENV BURP_HOME=/opt/burp \
    BURP_VERSION=${BURP_VERSION} \
    BURP_SHA256=${BURP_SHA256}

RUN test -n "$BURP_VERSION" || { echo "BURP_VERSION build arg is required"; exit 1; } \
 && test -n "$BURP_SHA256"  || { echo "BURP_SHA256 build arg is required"; exit 1; }

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl tar unzip file \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/burp

# The optional context copy makes local artifacts usable; an empty dir is fine.
COPY burp/dist ./context-dist

# Acquire the artifact: remote URL first, else the context file.
RUN if [ -n "$BURP_DIST_URL" ]; then \
      printf 'downloading %s\n' "$BURP_DIST_URL" >&2; \
      curl -fsSL --retry 3 "$BURP_DIST_URL" -o dist.bin; \
    elif [ -s "context-dist/$BURP_JAR_NAME" ]; then \
      cp "context-dist/$BURP_JAR_NAME" dist.bin; \
    else \
      echo "no Burp distribution: set BURP_DIST_URL or add burp/dist/$BURP_JAR_NAME to the build context"; exit 1; \
    fi \
 && rm -rf context-dist

# Verify the checksum before any further use.
RUN printf '%s  dist.bin\n' "$BURP_SHA256" | sha256sum -c - \
 || { echo "checksum mismatch for the Burp distribution"; exit 1; }

# Locate the launchable jar: dist.bin may itself be the jar, or an archive.
RUN file dist.bin \
 && case "$(file -b dist.bin)" in \
      *"Zip archive"*) cp dist.bin "$BURP_JAR_NAME" ;; \
      *"gzip compressed"* | *"tar archive"*) \
          mkdir -p extracted \
          && tar -xzf dist.bin -C extracted \
          && find extracted -name 'burpsuite_pro.jar' -o -name 'burpsuite.jar' > .jarpaths \
          && test -s .jarpaths || { echo "no burpsuite jar found in the archive"; exit 1; } \
          && cp "$(head -n 1 .jarpaths)" "$BURP_JAR_NAME" \
          && rm -rf extracted ;; \
      *) echo "unrecognized Burp distribution type (jar or tar.gz expected)"; exit 1 ;; \
    esac \
 && test -s "$BURP_JAR_NAME" \
 && rm -f dist.bin .jarpaths

# Isolated, unprivileged service account. State and secrets live on mounts
# (compose read_only + tmpfs), never in image layers.
RUN groupadd --gid 10002 burp \
 && useradd --uid 10002 --gid 10002 --create-home --home-dir /home/burp burp \
 && mkdir -p /state /app \
 && chown -R burp:burp /opt/burp /state /home/burp

COPY docker/burp-lib.sh docker/burp-entrypoint.sh \
     docker/burp-health.sh docker/burp-proof.sh /app/
RUN chmod 755 /app/burp-lib.sh /app/burp-entrypoint.sh /app/burp-health.sh /app/burp-proof.sh \
 && sed -i 's/\r$//' /app/burp-lib.sh /app/burp-entrypoint.sh /app/burp-health.sh /app/burp-proof.sh

USER burp
WORKDIR /app
ENTRYPOINT ["/app/burp-entrypoint.sh"]
