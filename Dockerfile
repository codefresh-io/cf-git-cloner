#moving to ubuntu instead of debian to solve high vulnerabilities
FROM ubuntu:noble-20241009

RUN apt-get update && \
  apt-get install -y curl bash openssl git && \
  apt-get clean

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get install git-lfs=3.5.1 && \
    git lfs install

#installing busybox
ARG BUSYBOX_VERSION=1:1.36.1-6ubuntu3

RUN apt-get install busybox=${BUSYBOX_VERSION} && \
    ln -s /bin/busybox /usr/bin/[[

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
    && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
