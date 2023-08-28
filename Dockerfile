#moving to ubuntu instead of debian to solve high vulnerabilities 
FROM ubuntu:jammy-20230804

RUN apt-get update && \
  apt-get install -y curl bash openssl  && \
  apt-get clean

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
  apt-get install -y git-lfs=3.4.0 busybox && \
  apt-get clean

RUN ln -s /bin/busybox /usr/bin/[[

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
   && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
