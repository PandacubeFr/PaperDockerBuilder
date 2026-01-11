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

# Get the API version from the jar
API_VERSION=$(unzip -p $APP_FILENAME META-INF/libraries.list | grep 'io.papermc.paper:paper-api:' | head -n 1 | awk '{print $2}' | cut -d':' -f3) # io.papermc.paper:paper-api:1.21.10-R0.1-SNAPSHOT
echo ""
echo "Paper API Version is: $API_VERSION"

echo ""
echo "=== Building Docker image ==="
docker build -t "$DOCKER_TAG" --build-arg RUNNABLE_SERVER_JAR="$APP_FILENAME" .
docker tag "$DOCKER_TAG" "$DOCKER_TAG_VERSION"


# Extract the patched jar from the image at path /data/bundle/versions/${MC_VERSION}
TEMP_CONTAINER_ID=$(docker create "$DOCKER_TAG")
docker cp $TEMP_CONTAINER_ID:/data/bundle/versions/${MC_VERSION}/paper-${MC_VERSION}.jar ./paper-server-${API_VERSION}.jar
docker rm $TEMP_CONTAINER_ID

mvn install:install-file -Dfile=./paper-server-${API_VERSION}.jar -DgroupId=io.papermc.paper -DartifactId=paper-server -Dversion=${API_VERSION} -Dpackaging=jar


echo ""
echo "✅ Docker images built successfully:"
echo "  - $DOCKER_TAG"
echo "  - $DOCKER_TAG_VERSION"
echo ""
echo "✅ Paper patched jar installed successfully on local Maven repository:"
echo "  - io.papermc.paper:paper-server:${API_VERSION}"
