#moving to ubuntu instead of debian to solve high vulnerabilities
FROM ubuntu:noble-20240114

RUN apt-get update && \
  apt-get install -y curl bash openssl git && \
  apt-get clean

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt list git-lfs -a && \
    apt-get install git-lfs=3.4.1-1 && \
    git lfs install

#installing busybox
ARG BUSYBOX_VERSION=1.31.0

RUN curl -sL https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}-defconfig-multiarch-musl/busybox-x86_64 -o busybox && \
    ls -l busybox && \
    chmod +x busybox && \
    mv busybox /usr/bin/ && \
    ls /usr/bin/busybox && \
    busybox | head -n 1

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
    && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
