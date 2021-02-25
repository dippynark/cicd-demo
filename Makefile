DOMAIN = dippynark.co.uk
GITHUB_BOT = dippynark-bot
GITHUB_OWNER = dippynark
GITHUB_REPOSITORY = cicd-demo

DOCKER_IMAGE = dippynark/cicd-demo:v1.0.0

CACHE_DIR = cache
STAGING_DIR = staging
MANIFESTS_DIR = manifests

HELM_VERSION = 3.4.0
KFMT_VERSION = 0.4.1
KUBECTL_VERSION = 1.19

BOOKINFO_VERSION = release-1.9
FLUX_VERSION = 1.6.2
CERT_MANAGER_VERSION = 1.2.0
INGRESS_NGINX_VERSION = 0.44.0
LIGHTHOUSE_VERSION = 0.0.939
TEKTON_PIPELINES_VERSION = 0.21.0
TEKTON_DASHBOARD_VERSION = 0.14.0

SHELL=/bin/bash -o pipefail

istio:
	scripts/istio.sh

include lib.mk

generate: setup \
	bookinfo \
	flux \
	cert_manager \
	ingress_nginx \
	lighthouse \
	tekton_pipelines \
	tekton_dashboard \
	local \
	format \
	teardown

local:
	# Hydrate local chart
	helm template ./charts/local \
		--set domain=$(DOMAIN) \
		--set github.owner=$(GITHUB_OWNER) \
		--set github.repository=$(GITHUB_REPOSITORY) \
		> $(STAGING_DIR)/local.yaml
	# Replace Lighthouse values
	sed -i "s/DOMAIN/$(DOMAIN)/g" $(STAGING_DIR)/lighthouse.yaml
	sed -i "s/GITHUB_BOT/$(GITHUB_BOT)/g" $(STAGING_DIR)/lighthouse.yaml

docker_build:
	docker build \
		--build-arg HELM_VERSION=$(HELM_VERSION) \
		--build-arg KFMT_VERSION=$(KFMT_VERSION) \
		--build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) \
		-t $(DOCKER_IMAGE) $(CURDIR)

docker_push: docker_build
	docker push $(DOCKER_IMAGE)

docker_%: docker_build
	docker run -it \
		-w /workspace \
		-v $(CURDIR):/workspace \
		$(DOCKER_IMAGE) \
		make $*
