#!/bin/bash

URL_PROJECT='https://api.papermc.io/v2/projects/paper'

echo "Getting Paper last build id for MC "$MC_VERSION"..."

URL_VERSION=$URL_PROJECT'/versions/'$MC_VERSION

# get paper build version
if ! curl -s $URL_VERSION -o version_infos.json; then
	echo -e "Error: Can't join API"
    exit 1
fi


if ! jq -r '.builds[-1]' -e < version_infos.json > build_number.txt; then
	echo -e "API returned an error (probably MC_VERSION is not valid)"
    exit 1
fi

PAPER_BUILD=`cat build_number.txt`
URL_BUILD=$URL_VERSION'/builds/'$PAPER_BUILD


DOWNLOAD_REOBF=$URL_BUILD'/downloads/paper-'$MC_VERSION'-'$PAPER_BUILD'.jar'

# the runnable jar is actually paperclip
RUNNABLE_SERVER_JAR='Paper-'$MC_VERSION'-'$PAPER_BUILD'.jar'
#UBER_SERVER_JAR='Paper-uberjar-'$MC_VERSION'-'$PAPER_BUILD'.jar'

echo "Downloadling Paperclip for Paper-"$MC_VERSION"-"$PAPER_BUILD"..."
echo "From "$DOWNLOAD_REOBF
echo "To "$RUNNABLE_SERVER_JAR
curl -o $RUNNABLE_SERVER_JAR $DOWNLOAD_REOBF


DOCKER_TAG="cr.pandacube.fr/paper:"$MC_VERSION"-"$PAPER_BUILD
DOCKER_TAG_VERSION="cr.pandacube.fr/paper:"$MC_VERSION
echo "Building docker image with pre-downloaded and pre-patched files, with tag "$DOCKER_TAG
docker build --build-arg RUNNABLE_SERVER_JAR=$RUNNABLE_SERVER_JAR -t $DOCKER_TAG .
docker tag $DOCKER_TAG $DOCKER_TAG_VERSION


echo "Pushing image to Pandacube's container registry"
docker push $DOCKER_TAG
docker push $DOCKER_TAG_VERSION

