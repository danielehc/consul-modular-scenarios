
ARG BASE_VERSION
ARG APP_VERSION

FROM hashicorpdemoapp/payments:${APP_VERSION} as base

FROM danielehc/consul-instruqt-base:${BASE_VERSION}

COPY --from=base spring-boot-payments-*.jar /bin/spring-boot-payments.jar

RUN apk add --no-cache openjdk11-jre

CMD ["java", "-jar", "/bin/spring-boot-payments.jar"]
