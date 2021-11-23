
ARG BASE_VERSION
ARG APP_VERSION

FROM hashicorpdemoapp/product-api:${APP_VERSION} as base

FROM danielehc/consul-instruqt-base:${BASE_VERSION}


COPY --from=base /app/product-api /bin/product-api
COPY wait.sh /bin/
COPY conf.json /home/app/conf.json

ENV CONFIG_FILE /home/app/conf.json

RUN apk add --no-cache postgresql-client && \
chmod +x /bin/product-api && \
chmod +x /bin/wait.sh

CMD ["/bin/product-api"]