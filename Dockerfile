FROM alpine:3.5

RUN apk add --update git bash openssl && \
    wget -qO- https://github.com/git-lfs/git-lfs/releases/download/v2.3.4/git-lfs-linux-amd64-2.3.4.tar.gz | tar xz && \
    mv git-lfs-*/git-lfs /usr/bin/ && rm -rf git-lfs-* && git lfs install

#add ssh record on which ssh key to use
COPY ./.ssh/ /root/.ssh/

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

CMD ["/run/start.sh"]