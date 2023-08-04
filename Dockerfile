#moving to ubuntu instead of debian to solve high vulnerabilities 
FROM ubuntu:latest

RUN apt-get update -y && apt-get install git bash openssl -y

RUN apt-get install git-lfs && \
 git lfs install

RUN apt-get update -y && apt-get install busybox -y && ln -s /bin/busybox /usr/bin/[[

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
   && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
