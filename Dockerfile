ARG KUBECTL_VERSION=latest
FROM bitnami/kubectl:$KUBECTL_VERSION

USER root
RUN apt-get update && apt-get -y install --no-install-recommends jq

# symlink kubectl to the standard path location
RUN ln -s /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl

ADD assets /opt/resource/
RUN chmod +x /opt/resource/*
