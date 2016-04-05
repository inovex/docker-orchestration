FROM redis:3-alpine
MAINTAINER Johannes M. Scheuermann <johannes.scheuermann@inovex.de>

COPY start-redis-slave.sh /start-redis-slave.sh

RUN chmod a+x /start-redis-slave.sh
CMD /start-redis-slave.sh
