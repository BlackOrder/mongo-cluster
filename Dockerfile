FROM mongo:latest


RUN openssl rand -base64 756 > /mongodb_key
RUN chmod 400 /mongodb_key
RUN chown 999:999 /mongodb_key

RUN echo 'sleep 3' > /data/db/init_rs.sh
RUN echo 'mongosh -u "$1" -p "$2" --eval "rs.initiate()"' >> /data/db/init_rs.sh
RUN echo 'rm -- "$0"' >> /data/db/init_rs.sh
RUN chmod +x /data/db/init_rs.sh
RUN chown 999:999 /data/db/init_rs.sh

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--bind_ip_all", "--keyFile", "/mongodb_key", "--replSet", "rs"]
