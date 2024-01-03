FROM mongo:latest

LABEL org.opencontainers.image.authors="𝓑𝓵𝓪𝓬𝓴𝓞𝓻𝓭𝓮𝓻"
LABEL org.opencontainers.image.source="https://github.com/BlackOrder/mongo-cluster"

ENV MONGODB_HOST 'mongodb'

COPY ./init_rs.sh /data/db/init_rs.sh
RUN chown 999:999 /data/db/init_rs.sh

RUN sed -i "s/unset \"\${\!MONGO_INITDB.*/if [ -f \"\/data\/db\/init_rs\.sh\" ]; then\n\t\t\/data\/db\/init_rs\.sh \"\$MONGO_INITDB_ROOT_USERNAME\" \"\$MONGO_INITDB_ROOT_PASSWORD\" \&\n\tfi\n\n\tunset \"\${\!MONGO_INITDB_@}\"/g" /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--bind_ip_all", "--keyFile", "/data/db/mongodb_key", "--replSet", "rs"]
