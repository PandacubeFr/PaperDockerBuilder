FROM eclipse-temurin:21-jdk-alpine

ARG RUNNABLE_SERVER_JAR

# create directories
WORKDIR /data
RUN mkdir bin bundle workdir

# add executable files
ADD $RUNNABLE_SERVER_JAR bin/paper.jar
ADD run.sh bin/run.sh

# download paper libraries and apply patches
RUN java -DbundlerRepoDir=/data/bundle -Dpaperclip.patchonly=true -jar /data/bin/paper.jar

# configure max heap size
ENV MAXMEM=1024M

EXPOSE 25565
VOLUME /data/workdir

WORKDIR /data/workdir
CMD ["sh", "/data/bin/run.sh"]
