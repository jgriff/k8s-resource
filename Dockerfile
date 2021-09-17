ARG KUBECTL_VERSION=1.20
FROM bitnami/kubectl:$KUBECTL_VERSION

USER root
RUN apt-get update && apt-get -y install --no-install-recommends jq

ADD assets /opt/resource/
RUN chmod +x /opt/resource/*
