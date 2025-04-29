FROM --platform=$BUILDPLATFORM swift:6.1.0 AS build
WORKDIR /workspace

RUN swift sdk install \
    https://download.swift.org/swift-6.1-branch/static-sdk/swift-6.1-DEVELOPMENT-SNAPSHOT-2025-03-25-a/swift-6.1-DEVELOPMENT-SNAPSHOT-2025-03-25-a_static-linux-0.0.1.artifactbundle.tar.gz \
    --checksum 2b73c30ec402f443857e6cd2ac06b8525f186e889a7a727af05601629148fe6a

RUN mkdir -p /workspace/OluttaBackend
COPY ./OluttaShared /workspace/OluttaShared/
COPY ./OluttaBackend/Package.swift ./OluttaBackend/Package.resolved /workspace/OluttaBackend/
COPY ./OluttaBackend/build_scripts /workspace/OluttaBackend/scripts
COPY ./OluttaBackend/Sources /workspace/OluttaBackend/Sources

WORKDIR /workspace/OluttaBackend

RUN --mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
    swift package \
        --cache-path /workspace/.spm-cache \
        --only-use-versions-from-resolved-file \
        resolve

ARG TARGETPLATFORM
RUN --mount=type=cache,target=/workspace/.build,id=build-$TARGETPLATFORM \
    --mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
    scripts/build-release.sh && \
    mkdir -p dist && \
    cp .build/release/OluttaBackend dist

FROM --platform=$BUILDPLATFORM swift:6.1.0 AS release
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/OluttaBackend/dist/OluttaBackend /usr/local/bin/OluttaBackend
ENTRYPOINT ["/usr/local/bin/OluttaBackend"]
