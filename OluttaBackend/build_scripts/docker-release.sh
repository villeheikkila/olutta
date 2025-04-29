#!/bin/bash

echo "Update '$(basename "${BASH_SOURCE[0]}")' to use your own '--tag' or use the '.github/workflows/docker-push.yaml' GitHub workflow"
exit 1

set -eo pipefail

pushd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null

docker buildx build \
	--platform linux/amd64,linux/arm64 \
	--tag villeheikkila/ylahylly \
	--push \
	.
