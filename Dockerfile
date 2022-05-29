FROM alpine:3.15

RUN apk add --no-cache git=~2.32.0 bash openssh

# install git-lfs
RUN apk add --no-cache --virtual deps openssl && \
    export ARCH=$([[ "$(uname -m)" == "aarch64" ]] && echo "arm64" || echo "amd64") && \
    wget -qO- https://github.com/git-lfs/git-lfs/releases/download/v2.12.1/git-lfs-linux-${ARCH}-v2.12.1.tar.gz | tar xz && \
    mv git-lfs /usr/bin/ && \
    git lfs install && \
    apk del deps

# add ssh record on which ssh key to use
COPY ./.ssh/ /root/.ssh/

# add fingerprint for major git providers
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

CMD ["/run/start.sh"]
