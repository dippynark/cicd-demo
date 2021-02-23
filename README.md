# CI/CD Demo

## Setup

Create cluster:

```sh
gcloud container clusters create cicd-demo
```

Install Flux:

```sh
kubectl apply \
  -f manifests/cluster/namespaces/flux.yaml \
  -f manifests/cluster/clusterrolebindings/flux.yaml \
  -f manifests/cluster/clusterroles/flux.yaml \
  -f manifests/namespaces/flux
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-deploy
  namespace: flux
EOF
```

Create secrets:

```sh
HMAC_TOKEN=$(openssl rand -hex 32)
GITHUB_BOT="dippynark-bot"
GITHUB_TOKEN=""
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: lighthouse-hmac-token
  namespace: lighthouse
stringData:
  hmac: $HMAC_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: tekton-git
  namespace: lighthouse
  annotations:
    tekton.dev/git-0: https://github.com
stringData:
  username: $GITHUB_BOT
  password: $GITHUB_TOKEN
EOF
```

```sh
brew install fluxcd/tap/flux
```

```sh
make docker_generate
```
