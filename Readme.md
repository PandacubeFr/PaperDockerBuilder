Docker Compose Example

```yml
version: "3"
services:
  paper:
    image: "pandacubefr/paper:(version)"
    container_name: (server name)
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