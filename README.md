# CI/CD Demo

## Setup

Create cluster:

```sh
gcloud container clusters create cicd-demo
```

Setup secret variables:

```sh
GITHUB_USERNAME="dippynark-bot"
GITHUB_EMAIL="lukeaddison.785@gmail.com"
# Personal acces token with `repo` ticked
GITHUB_TOKEN=""
HMAC_TOKEN=$(openssl rand -hex 32)
```

Install Flux:

```sh
# Clone repository
# Add bot user as a collaborator
kubectl apply \
  -f manifests/cluster/namespaces/flux.yaml \
  -f manifests/cluster/clusterrolebindings/flux.yaml \
  -f manifests/cluster/clusterroles/flux.yaml \
  -f manifests/namespaces/flux
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-auth
  namespace: flux
stringData:
  GIT_AUTHUSER: $GITHUB_USERNAME
  GIT_AUTHKEY: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-deploy
  namespace: flux
EOF
```

Flux should sync all manifests.

Create Lighthouse and Tekton secrets:

```sh
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
  name: lighthouse-oauth-token
  namespace: lighthouse
stringData:
  oauth: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: tekton-git
  namespace: lighthouse
  annotations:
    tekton.dev/git-0: https://github.com
type: kubernetes.io/basic-auth
stringData:
  username: $GITHUB_USERNAME
  password: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: tekton-git-identity
  namespace: lighthouse
stringData:
  GIT_AUTHOR_NAME: $GITHUB_USERNAME
  GIT_AUTHOR_EMAIL: $GITHUB_EMAIL
  GIT_COMMITTER_NAME: $GITHUB_USERNAME
  GIT_COMMITTER_EMAIL: $GITHUB_EMAIL
---
apiVersion: v1
kind: Secret
metadata:
  name: webhook-certs
  namespace: tekton-pipelines
EOF
```

Currently, cert-manager should be trying to provision a certificate for your Lighthouse webhook. We
should fix this.

You should have a LoadBalancer service for Nginx ingress:

```sh
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Set your domain at the top of the Makefile, regenerate (`make docker_generate`), commit and push
changes and point Lighthouse hook domain (`lighthouse.DOMAIN`) and the Tekton Dashboard domain
(`tekton.DOMAIN`) at the Nginx ingress external IP. Eventually the certificate should be
provisioned:

```sh
kubectl get certificate -n lighthouse hook-lighthouse-tls
```

Finally we create a webhook in the GitHub repository pointing at Lighthouse with the following
non-default options:

- Payload URL: `https://lighthouse.DOMAIN/hook`
- Content type: `application/json`
- Secret: `echo $HMAC_TOKEN`
- Which events would you like to trigger this webhook?: `Send me everything.`

## Test

Try to make a change and watch it sync to the cluster.

```sh
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097
```

```sh
make docker_generate
```
