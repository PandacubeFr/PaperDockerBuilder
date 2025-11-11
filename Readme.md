# PaperDockerBuilder

Jenkins pipeline to build a Docker image of Paper.

## Disclaimer

This project is not meant to provide an already working docker image containing Paper, due to licensing reason with the MC source code.

You have to install the Jenkins pipeline yourself, or run the `build.sh` script provided.

## Project structure

```bash
build.sh    # build the image in a standalone way (not used by the pipeline)
Dockerfile  # used to build the Docker image
Jenkinsfile # the pipeline file
Readme.md   # you are reading this file
run.sh      # entrypoint of the Docker image
```

## Pipeline process

1. Fetches the information about the latest build of Paper for the provided MC version, from the [PaperMC API](https://api.papermc.io/v2/projects/paper)
2. Downloads the Paper jar file.
3. Builds the docker image with the downloaded jar and the entrypoint script, ensuring libraries are downloaded and Paper patch is applied.
4. Pushes the image to the container registry with the tags `$mc_version` (e.g. `1.20.1`) and `$mc_version-$paper_build` (e.g. `1.20.1-196`)

## Docker Compose Example

```yml
services:
  server:
    image: "cr.pandacube.fr/paper:(version)"
    stdin_open: true # docker run -i
    tty: true        # docker run -t
    user: "1000:1000" # uid and gid of owner of working dir 
    environment:
      - MAXMEM=2048M # Java max heap size
    restart: always
    volumes:
      - .:/data/workdir
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "0.0.0.0:(port):25565"
```