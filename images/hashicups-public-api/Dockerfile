ARG BASE_VERSION
ARG APP_VERSION

FROM hashicorpdemoapp/public-api:${APP_VERSION} as application

FROM danielehc/consul-instruqt-base:${BASE_VERSION}

COPY --from=application app/public-api /bin/public-api

ENV BIND_ADDRESS :8080
ENV PRODUCT_API_URI http://localhost:9090
ENV PAYMENT_API_URI http://localhost:1800

CMD ["/bin/public-api"]