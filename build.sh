#!/bin/bash

# Script to build Paper Docker image locally
# Usage: ./build.sh <MC_VERSION>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <MC_VERSION>"
    echo "Example: $0 1.20.1"
    exit 1
fi

MC_VERSION=$1
APP_GIT_COMMIT=$(git rev-parse --short HEAD)
USER_AGENT="PaperDockerBuilder/${APP_GIT_COMMIT} (https://github.com/PandacubeFr/PaperDockerBuilder)"

URL_BASE="https://fill.papermc.io/v3/projects/paper"
URL_BUILD_INFOS="${URL_BASE}/versions/${MC_VERSION}/builds/latest"

DOCKER_TAG_BASE="cr.pandacube.fr/paper"

echo "=== Getting build data ==="
curl -A "$USER_AGENT" -L -s "$URL_BUILD_INFOS" -o build_infos.json

APP_BUILD=$(jq -r '.id' build_infos.json)
URL_DOWNLOAD=$(jq -r '.downloads["server:default"].url' build_infos.json)
APP_FILENAME="Paper-${MC_VERSION}-${APP_BUILD}.jar"

DOCKER_TAG="${DOCKER_TAG_BASE}:${MC_VERSION}-${APP_BUILD}"
DOCKER_TAG_VERSION="${DOCKER_TAG_BASE}:${MC_VERSION}"

echo "Paper version ${MC_VERSION} build #${APP_BUILD}"

echo ""
echo "=== Downloading jar ==="
curl -A "$USER_AGENT" -L -o "$APP_FILENAME" "$URL_DOWNLOAD"
echo "Downloaded: $APP_FILENAME"

echo ""
echo "=== Building Docker image ==="
docker build -t "$DOCKER_TAG" --build-arg RUNNABLE_SERVER_JAR="$APP_FILENAME" .
docker tag "$DOCKER_TAG" "$DOCKER_TAG_VERSION"

echo ""
echo "✅ Docker images built successfully:"
echo "  - $DOCKER_TAG"
echo "  - $DOCKER_TAG_VERSION"
