FROM eclipse-temurin:17-jdk

ARG RUNNABLE_SERVER_JAR

WORKDIR /data
RUN mkdir jar bundle workdir

ADD $RUNNABLE_SERVER_JAR jar/paper.jar

RUN java -DbundlerRepoDir=/data/bundle -Dpaperclip.patchonly=true -jar

ENV MAXMEM=1024M

EXPOSE 25565
VOLUME /data/workdir

WORKDIR workdir
CMD java -Xmx$MAXMEM -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
    -XX:G1ReservePercent=15 -XX:G1NewSizePercent=20 -XX:G1MaxNewSizePercent=30 \
    -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
    -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 \
    -XX:MaxHeapFreeRatio=30 -XX:MinHeapFreeRatio=5 \
    -DbundlerRepoDir=/data/bundle \
    -jar /data/jar/paper.jar nogui
