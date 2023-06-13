#moving to ubuntu instead of debian to solve high vulnerabilities 
FROM ubuntu:jammy-20230425

RUN apt-get update -y && apt-get install git bash openssl -y

RUN apt-get install git-lfs && \
 git lfs install

RUN apt-get update -y && apt-get install busybox -y && ln -s /bin/busybox /usr/bin/[[
# add ssh record on which ssh key to use
COPY ./.ssh/ /root/.ssh/

# add fingerprint for major git providers
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

# USER nodeuser
RUN addgroup --gid 3000 nodegroup \
   && adduser --uid 3000 --home /root --ingroup nodegroup --shell /bin/sh  --gecos ""  --disabled-password nodeuser \
   && chown -R $(id -g nodeuser) /root \
   && chgrp -R $(id -g nodeuser) /root \
   && chmod -R g+rwX /root
USER nodeuser

CMD ["/run/start.sh"]
