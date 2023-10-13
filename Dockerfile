#moving to ubuntu instead of debian to solve high vulnerabilities
FROM ubuntu:jammy-20231004

RUN apt-get update && \
  apt-get install -y curl bash openssl git && \
  apt-get clean

ARG GIT_LFS_VERSION=3.4.0
ARG TARGETPLATFORM

# installing git-lfs
RUN case ${TARGETPLATFORM} in \
   "linux/amd64")  OS_ARCH=amd64  ;; \
   "linux/arm64")  OS_ARCH=arm64  ;; \
    esac \
    && curl -sL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${OS_ARCH}-v${GIT_LFS_VERSION}.tar.gz -o "git-lfs.tar.gz" && \
    tar -xvzf "git-lfs.tar.gz" && \
    chmod +x git-lfs-${GIT_LFS_VERSION}/install.sh && \
    rm git-lfs.tar.gz && \
    git-lfs-${GIT_LFS_VERSION}/install.sh

#installing busybox
ARG BUSYBOX_VERSION=1.31.0

RUN curl -sL https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}-defconfig-multiarch-musl/busybox-x86_64 -o busybox && \
    ls -l busybox && \
    chmod +x busybox && \
    mv busybox /usr/bin/ && \
    ls /usr/bin/busybox && \
    busybox | head -n 1


RUN ln -s /bin/busybox /usr/bin/[[

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
   && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
