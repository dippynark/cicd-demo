# CI/CD Demo

This is a demo repository to complement my [Kubernetes-Native CI/CD blog
post](https://www.jetstack.io/blog/kubernetes-native-cicd/).

Prerequisites:

- [gcloud](https://cloud.google.com/sdk/docs/install) configured for a GCP account with available
  credits (using the [Free Tier](https://cloud.google.com/free) or otherwise)
- kubectl
- Docker
- [flux](https://toolkit.fluxcd.io/guides/installation/#install-the-flux-cli)
- GitHub user account
- GitHub bot account
- Domain to configure hostnames:
  - tekton
  - lighthouse

## Setup

We will perform the following steps:
- Provision a GKE cluster suitable for running the [Kubernetes Cluster API Provider
  Kubernetes](https://github.com/dippynark/cluster-api-provider-kubernetes)
  - This is an experimental infrastructure provider suitable for testing
- Install Flux to sync repository manifests
- Create missing Secrets
- Setup domain
- Setup GitHub webhook

Create GKE cluster:

```sh
# We will use the Kubernetes Cluster API infrastructure provider to provision workload clusters
# https://github.com/dippynark/cluster-api-provider-kubernetes
gcloud container clusters create management \
  --image-type=UBUNTU \
  --machine-type=n1-standard-2

CLUSTER_CIDR=`gcloud container clusters describe management --format="value(clusterIpv4Cidr)"`
gcloud compute firewall-rules create allow-management-cluster-pods-ipip \
  --source-ranges=$CLUSTER_CIDR \
  --allow=ipip

kubectl apply -f https://raw.githubusercontent.com/dippynark/cluster-api-provider-kubernetes/v0.3.3/hack/forward-ipencap.yaml
```

Clone this repository and set the following variables:

```sh
GITHUB_OWNER="dippynark"
GITHUB_REPOSITORY="cicd-demo"
# Personal access token for owner account with full `repo` permissions
export GITHUB_TOKEN=""

GITHUB_BOT_USERNAME="dippynark-bot"
GITHUB_BOT_EMAIL="lukeaddison.785@gmail.com"
# Personal access token for bot account with full `repo` permissions
GITHUB_BOT_TOKEN=""

HMAC_TOKEN=$(openssl rand -hex 32)

DOMAIN="dippynark.co.uk"
```

Modify the
[clusters/management/flux-system/cluster-sync.yaml](clusters/management/flux-system/cluster-sync.yaml)
management configuration file as required (i.e. replacing `dippynark/cicd-demo`, `dippynark-bot` and
`dippynark.co.uk` with `$GITHUB_OWNER/$GITHUB_REPOSITORY`, `$GITHUB_BOT_USERNAME` and `$DOMAIN`
respectively.) and update the [OWNERS file](https://www.kubernetes.dev/docs/guide/owners/):

```sh
cat <<EOF > OWNERS
approvers:
- $GITHUB_OWNER
reviewers:
- $GITHUB_OWNER
EOF
```

Commit the changes, push to the main branch and add the bot account as a collaborator.

Bootstrap the management cluster:

```sh
# This command may fail the first time due to missing CRDs; this is expected
flux bootstrap github \
  --owner=$GITHUB_OWNER \
  --repository=$GITHUB_REPOSITORY \
  --path=clusters/management \
  --personal
```

Once Flux has performed its initial sync, create the Git secret for bootstrapping workload clusters:

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: git-auth
  namespace: infrastructure
stringData:
  GITHUB_TOKEN: $GITHUB_TOKEN
  GITHUB_OWNER: $GITHUB_OWNER
  GITHUB_REPOSITORY: $GITHUB_REPOSITORY
EOF
```

Eventually the workload clusters should be provisioned and bootstrapped:

```sh
kubectl get kubernetesclusters,kubernetesmachines -n infrastructure
```

Once the manifests have synced, create the Lighthouse secrets:

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: lighthouse-helm-release
  namespace: lighthouse
stringData:
  values.yaml: |
    oauthToken: $GITHUB_BOT_TOKEN
    hmacToken: $HMAC_TOKEN
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
  username: $GITHUB_BOT_USERNAME
  password: $GITHUB_BOT_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: tekton-git-identity
  namespace: lighthouse
stringData:
  GIT_AUTHOR_NAME: $GITHUB_BOT_USERNAME
  GIT_AUTHOR_EMAIL: $GITHUB_BOT_EMAIL
  GIT_COMMITTER_NAME: $GITHUB_BOT_USERNAME
  GIT_COMMITTER_EMAIL: $GITHUB_BOT_EMAIL
EOF
```

Currently, [cert-manager](https://github.com/jetstack/cert-manager) should be trying to provision a
certificate for your Lighthouse webhook and Tekton dashboard but it cannot since we haven't
configured DNS yet; we will configure this now.

You should have a LoadBalancer Service for Nginx ingress:

```sh
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Point the Lighthouse webhook domain (`lighthouse.$DOMAIN`) and the Tekton Dashboard domain
(`tekton.$DOMAIN`) at the Nginx ingress external IP. Eventually the certificates should be
provisioned:

```sh
kubectl get certificate -n lighthouse lighthouse-hook-tls
kubectl get certificate -n tekton-pipelines tekton-dashboard-tls
```

Finally, we create a webhook in the GitHub repository pointing at the Lighthouse webhook with the
following non-default options:

- Payload URL: `https://lighthouse.$DOMAIN/hook`
- Content type: `application/json`
- Secret: `$HMAC_TOKEN`
- Which events would you like to trigger this webhook?: `Send me everything.`

## Usage

Generate [bases](config/bases):

```sh
make docker_generate
```

Access workload cluster:

```sh
CLUSTER_NAME="development"
make get_kubeconfig_$CLUSTER_NAME
export KUBECONFIG=kubeconfig
kubectl get nodes
```

Promote cluster:

```sh
make docker_promote SOURCE=development DESTINATION=staging
```
