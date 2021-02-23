FROM debian:10.6

RUN apt-get update && apt-get install -y \
  curl \
  make \
  git

# kfmt
ARG KFMT_VERSION
RUN curl -LO "https://github.com/dippynark/kfmt/releases/download/v${KFMT_VERSION}/kfmt-linux-amd64" && \
  chmod +x kfmt-linux-amd64 && \
  mv kfmt-linux-amd64 /usr/local/bin/kfmt

# kustomize
ARG KUSTOMIZE_VERSION
RUN curl -LO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" && \
  tar xvf "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" && \
  chmod +x kustomize && \
  mv kustomize /usr/local/bin && \
  rm "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"

# clusterctl
ARG CLUSTERCTL_VERSION
RUN curl -LO "https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-linux-amd64" && \
  chmod +x ./clusterctl-linux-amd64 && \
  mv clusterctl-linux-amd64 /usr/local/bin/clusterctl

# flux
ARG FLUX_VERSION
RUN curl -LO "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz" && \
  tar xvf "flux_${FLUX_VERSION}_linux_amd64.tar.gz" && \
  mv flux /usr/local/bin && \
  rm "flux_${FLUX_VERSION}_linux_amd64.tar.gz"

# kubectl
ARG KUBECTL_VERSION
RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-${KUBECTL_VERSION}.txt)/bin/linux/amd64/kubectl" && \
  chmod +x kubectl && \
  mv kubectl /usr/local/bin
