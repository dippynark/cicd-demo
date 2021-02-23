FROM debian:10.6

RUN apt-get update && apt-get install -y \
  curl \
  make \
  jq

# helm
ARG HELM_VERSION
ENV DESIRED_VERSION="v${HELM_VERSION}"
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# kfmt
ARG KFMT_VERSION
RUN curl -LO "https://github.com/dippynark/kfmt/releases/download/v${KFMT_VERSION}/kfmt-linux-amd64" && \
  chmod +x kfmt-linux-amd64 && \
  mv kfmt-linux-amd64 /usr/local/bin/kfmt

# istioctl
ARG ISTIO_VERSION
RUN curl -L https://istio.io/downloadIstioctl | sh - && \
  mv "${HOME}/.istioctl/bin/istioctl" /usr/local/bin && \
  rm -rf "${HOME}/.istioctl"

# kubectl
ARG KUBECTL_VERSION
RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-${KUBECTL_VERSION}.txt)/bin/linux/amd64/kubectl" && \
  chmod +x kubectl && \
  mv kubectl /usr/local/bin
