FROM bitnami/kubectl:1.18

USER root
RUN apt-get update && apt-get -y install --no-install-recommends jq

ADD scripts/ /opt/resource/
RUN chmod +x /opt/resource/*
