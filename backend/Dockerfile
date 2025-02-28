FROM --platform=$BUILDPLATFORM swift:6.0.3 AS build
WORKDIR /workspace
RUN swift sdk install \
	https://download.swift.org/swift-6.0.3-release/static-sdk/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
	--checksum 67f765e0030e661a7450f7e4877cfe008db4f57f177d5a08a6e26fd661cdd0bd

COPY ./Package.swift ./Package.resolved /workspace/
RUN --mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
	swift package \
		--cache-path /workspace/.spm-cache \
		--only-use-versions-from-resolved-file \
		resolve

COPY ./build_scripts /workspace/scripts
COPY ./Sources /workspace/Sources
COPY ./Tests /workspace/Tests
ARG TARGETPLATFORM
RUN --mount=type=cache,target=/workspace/.build,id=build-$TARGETPLATFORM \
	--mount=type=cache,target=/workspace/.spm-cache,id=spm-cache \
	scripts/build-release.sh && \
	mkdir -p dist && \
	cp .build/release/Ylahylly dist

FROM --platform=$BUILDPLATFORM swift:6.0.3  AS release
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/dist/Ylahylly /usr/local/bin/Ylahylly
ENTRYPOINT ["/usr/local/bin/ylahylly"]
