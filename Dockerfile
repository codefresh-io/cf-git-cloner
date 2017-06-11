FROM alpine:3.5

RUN apk add --update git bash

#add ssh record on which ssh key to use
COPY ./.ssh/ /root/.ssh/

COPY ./start.sh /run/start.sh
RUN chmod +x /run/start.sh

CMD ["/run/start.sh"]