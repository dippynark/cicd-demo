# CI/CD Demo

Prerequisites:

- Docker
- kubectl
- GitHub user account
- GitHub bot account
- A domain

## Setup

Create cluster:

```sh
gcloud container clusters create cicd-demo
```

Clone repository and set the following variables at the top of the Makefile:

- DOMAIN - Domain to expose Lighthouse hook and Tekton dashboard
- GITHUB_BOT - GitHub user used for automation
- GITHUB_OWNER - Owner of cloned repository
- GITHUB_REPOSITORY - Name of cloned repository

Run `make docker_generate` to apply the changes, update OWNERS file, commit changes and push to main
branch. Add the bot account as a collaborator.

Setup variables:

```sh
GITHUB_BOT="dippynark-bot"
GITHUB_EMAIL="lukeaddison.785@gmail.com"
# Personal access token for bot account with full `repo` permissions
GITHUB_TOKEN=""
HMAC_TOKEN=$(openssl rand -hex 32)
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
  name: flux-git-auth
  namespace: flux
stringData:
  GIT_AUTHUSER: $GITHUB_BOT
  GIT_AUTHKEY: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: flux-git-deploy
  namespace: flux
EOF
```

Flux should sync all manifests to the cluster.

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
  username: $GITHUB_BOT
  password: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: tekton-git-identity
  namespace: lighthouse
stringData:
  GIT_AUTHOR_NAME: $GITHUB_BOT
  GIT_AUTHOR_EMAIL: $GITHUB_EMAIL
  GIT_COMMITTER_NAME: $GITHUB_BOT
  GIT_COMMITTER_EMAIL: $GITHUB_EMAIL
---
apiVersion: v1
kind: Secret
metadata:
  name: webhook-certs
  namespace: tekton-pipelines
EOF
```

Currently, cert-manager should be trying to provision a certificate for your Lighthouse webhook and
Tekton dashboard but it cannot since which haven't configured DNS yet. We should fix this.

You should have a LoadBalancer Service for Nginx ingress:

```sh
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Point the Lighthouse webhook domain (`lighthouse.DOMAIN`) and the Tekton Dashboard domain
(`tekton.DOMAIN`) at the Nginx ingress external IP. Eventually the certificates should be
provisioned:

```sh
kubectl get certificate -n lighthouse lighthouse-hook-tls
kubectl get certificate -n tekton-pipelines tekton-dashboard-tls
```

Finally, we create a webhook in the GitHub repository pointing at the Lighthouse webhook with the
following non-default options:

- Payload URL: `https://lighthouse.DOMAIN/hook`
- Content type: `application/json`
- Secret: `echo $HMAC_TOKEN`
- Which events would you like to trigger this webhook?: `Send me everything.`
