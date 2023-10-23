#moving to ubuntu instead of debian to solve high vulnerabilities
FROM ubuntu:jammy-20231004

RUN apt-get update && \
  apt-get install -y curl bash openssl git && \
  apt-get clean

# git-lfs v3.4.0 - last available at the 23.10.2023 and it contains bug. Don't update to the version 3.4.0 !!!
# https://codefresh-io.atlassian.net/browse/CR-20633
# Next preferred version must be >=3.4.1 and should be tested
RUN apt-get install git-lfs=3.0.2-1 && \
 git lfs install

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
