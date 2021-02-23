FROM debian:10.6

RUN apt-get update && apt-get install -y \
  curl \
  make

# helm
ARG HELM_VERSION
ENV DESIRED_VERSION="v${HELM_VERSION}"
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
ENV HELM_CACHE_HOME="/helm/cache" HELM_CONFIG_HOME="/helm/config" HELM_DATA_HOME="/helm/data"
RUN mkdir -p $HELM_CACHE_HOME $HELM_CONFIG_HOME $HELM_DATA_HOME
RUN helm repo add jenkins-x http://chartmuseum.jenkins-x.io && \
  helm repo add fluxcd https://charts.fluxcd.io

# kfmt
ARG KFMT_VERSION
RUN curl -LO "https://github.com/dippynark/kfmt/releases/download/v${KFMT_VERSION}/kfmt-linux-amd64" && \
  chmod +x kfmt-linux-amd64 && \
  mv kfmt-linux-amd64 /usr/local/bin/kfmt

WORKDIR /workspace
