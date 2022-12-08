#!/bin/bash

URL_PROJECT='https://api.papermc.io/v2/projects/paper'

echo "Getting Paper last build id for MC "$MC_VERSION"..."

URL_VERSION=$URL_PROJECT'/versions/'$MC_VERSION

# get paper build version
if ! curl -s $URL_VERSION -o version_infos.json; then
	echo -e "Error: Can’t join API"
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


#java -version

# run it to generate final jar, but not launching the actual server (-v option)

#echo "Running Paperclip..."
#mkdir bundle
#java -DbundlerRepoDir=bundle -Dpaperclip.patchonly=true -jar $RUNNABLE_SERVER_JAR


# important that versions/ comes first. It will be extracted first,
# and following extraction will not override any file
#find bundle/versions/ bundle/libraries/ -type f -name '*.jar' > jars.txt


DOCKER_TAG="pandacubefr/paper:"$MC_VERSION"-"$PAPER_BUILD
echo "Building docker image with pre-downloaded and pre-patched files, with tag "$DOCKER_TAG
docker build --build-arg RUNNABLE_SERVER_JAR=$RUNNABLE_SERVER_JAR -t $DOCKER_TAG -f Dockerfile.paper .

DOCKER_IMAGE_FILE="Paper-docker-"$MC_VERSION"-"$PAPER_BUILD".tar.gz"
echo "Saving docker image to "$DOCKER_IMAGE_FILE
docker save $DOCKER_TAG | gzip > $DOCKER_IMAGE_FILE

#mkdir uberjar
#for jar in `cat jars.txt`; do
#  unzip -d uberjar -nq $jar
#done

#(
#  cd uberjar
#  # exclude some stuff, especially about jar signature and stuff
#  rm -f META-INF/*.SF META-INF/*.DSA META-INF/*.RSA
#  # create the uber jar
#  zip -r '../'$UBER_SERVER_JAR *
#)

#mvn install:install-file -Dfile=$UBER_SERVER_JAR -DgroupId=io.papermc.paper -DartifactId=paper -Dversion=$MC_VERSION-$PAPER_BUILD-SNAPSHOT -Dpackaging=jar
