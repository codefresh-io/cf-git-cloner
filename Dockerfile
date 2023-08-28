#moving to ubuntu instead of debian to solve high vulnerabilities 
FROM ubuntu:jammy-20230804

RUN apt-get update && \
  apt-get install -y curl bash openssl git && \
  apt-get clean

ARG GIT_LFS_VERSION=3.4.0

RUN TARGETPLATFORM=linux/arm64 && \
    case ${TARGETPLATFORM} in \
   "linux/amd64")  OS_ARCH=amd64  ;; \
   "linux/arm64")  OS_ARCH=arm64  ;; \
    esac \
    && curl -sL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${OS_ARCH}-v${GIT_LFS_VERSION}.tar.gz -o "git-lfs.tar.gz" && \
    tar -xvzf "git-lfs.tar.gz" -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/git-lfs-${GIT_LFS_VERSION}/install.sh && \
    rm git-lfs.tar.gz

WORKDIR /usr/local/bin/git-lfs-${GIT_LFS_VERSION}
RUN pwd && echo 111111 && ls -l && bash install.sh

WORKDIR /app

RUN apt-get update && apt-get install -y busybox  && ln -s /bin/busybox /usr/bin/[[

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
   && adduser --uid 3000 --home /home/nodeuser --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser
USER nodeuser

CMD ["/run/start.sh"]
