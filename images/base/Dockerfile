
ARG ENVOY_VERSION
ARG CONSUL_VERSION
ARG FAKEAPP_VERSION

# FROM envoyproxy/envoy:${ENVOY_VERSION} as envoy-bin
FROM consul:${CONSUL_VERSION} as consul-bin
FROM vault:latest as vault-bin
FROM nicholasjackson/fake-service:${FAKEAPP_VERSION} AS application
FROM filebrowser/filebrowser:latest AS filebrowser


# FROM alpine:latest
FROM envoyproxy/envoy-alpine:${ENVOY_VERSION}

# COPY --from=envoy-bin /usr/local/bin/envoy /usr/local/bin/envoy
COPY --from=consul-bin /bin/consul /usr/local/bin/consul
COPY --from=vault-bin /bin/vault /usr/local/bin/vault
COPY --from=application /app/fake-service /usr/local/bin/fake-service
COPY --from=filebrowser /filebrowser /usr/local/bin/filebrowser

# https://stackoverflow.com/questions/66963068/docker-alpine-executable-binary-not-found-even-if-in-path
# https://www.gitmemory.com/issue/sgerrand/alpine-pkg-glibc/154/851078836
# RUN rm /usr/glibc-compat/lib/ld-linux-x86-64.so.2 && /usr/glibc-compat/sbin/ldconfig

## Install setcap for binary capabilities
RUN apk add --no-cache libcap
## Instal iptables for transparent proxies
RUN apk add --no-cache iptables

RUN apk add --no-cache -u bash vim curl bind-tools jq openssl dropbear dropbear-dbclient openssh-client

RUN mkdir /etc/dropbear
RUN chown 1000:1000 /etc/dropbear

RUN apk add --no-cache tini

ENV TERM=xterm
ENV PS1='🐳:\[\033[1;36m\]\u@\h: \[\033[1;34m\]\w\[\033[0;35m\] \[\033[1;36m\]\$ \[\033[0m\]'

## Give binaries the capability to run on privileged ports without using root
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/consul
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/fake-service
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/dropbear
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/filebrowser

## Add user wuth UID and GID 1000
RUN set -x ; addgroup --gid 1000 app && \
	adduser -D -G "app" \
    --shell "/bin/bash" \
	--home "/home/app" \
	--uid 1000 \
	"app"

## The image needs a cert-key pair to enable SSH automatically
## generate it with `ssh-keygen -t rsa -b 4096`
COPY ./ssh/id_rsa.pub /etc/dropbear/authorized_keys
COPY ./ssh/id_rsa.pub /home/app/.ssh/authorized_keys

COPY ./ssh/id_rsa.pub /home/app/.ssh
COPY ./ssh/id_rsa /home/app/.ssh
RUN chown -R 1000:1000 /home/app/.ssh

COPY ./filebrowser.json /.filebrowser.json
RUN chown -R 1000:1000 /.filebrowser.json
RUN touch /database.db && chown -R 1000:1000 /database.db

# RUN echo 'alias ssh="dbclient"' >> /home/app/.bashrc

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["/entrypoint.sh"]