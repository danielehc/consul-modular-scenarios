ARG BASE_VERSION
ARG APP_VERSION

FROM postgres:alpine as pgres
FROM hashicorpdemoapp/product-api-db:${APP_VERSION} as base

FROM danielehc/consul-instruqt-base:${BASE_VERSION} 


RUN apk add --no-cache postgresql postgresql-client postgresql-contrib

RUN mkdir /docker-entrypoint-initdb.d

COPY --from=pgres /usr/local/bin/docker-entrypoint.sh /usr/local/bin/

COPY products.sql /docker-entrypoint-initdb.d/
COPY pg_hba.conf /tmp/

RUN mkdir -p /var/run/postgresql && chown -R 1000:1000 /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# ENV POSTGRES_HOST_AUTH_METHOD trust
ENV POSTGRES_DB products
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD password
# # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && \
    chown -R 1000:1000 "$PGDATA" && \
    chmod 777 "$PGDATA" && \
    chown -R 1000:1000 /var/lib/postgresql
# VOLUME /var/lib/postgresql/data

# ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT

EXPOSE 5432
CMD ["docker-entrypoint.sh", "postgres"]



# CMD ["postgres", "--version"]