DOCKER_IMAGE = dippynark/cicd-demo:v1.0.0

DOMAIN = dippynark.co.uk
GITHUB_USERNAME = dippynark-bot
GITHUB_OWNER = dippynark
GITHUB_REPOSITORY = cicd-demo

STAGING_DIR = staging
MANIFESTS_DIR = manifests

HELM_VERSION = 3.4.0
KFMT_VERSION = 0.4.1

CERT_MANAGER_VERSION = 1.2.0
NGINX_INGRESS_VERSION = 0.44.0
LIGHTHOUSE_VERSION = 0.0.922
TEKTON_PIPELINES_VERSION = 0.21.0
TEKTON_DASHBOARD_VERSION = 0.14.0
FLUX_VERSION = 1.6.2

SHELL=/bin/bash -o pipefail

generate: pre cert_manager nginx nginx_ingress tekton_pipelines lighthouse flux format post

nginx:
	cp config/nginx.yaml $(STAGING_DIR)

pre:
	helm repo update
	rm -rf $(STAGING_DIR) $(MANIFESTS_DIR)
	mkdir -p $(STAGING_DIR) $(MANIFESTS_DIR)

cert_manager:
	curl -L https://github.com/jetstack/cert-manager/releases/download/v$(CERT_MANAGER_VERSION)/cert-manager.yaml \
		-o $(STAGING_DIR)/cert-manager.yaml
	cp config/cert-manager/clusterissuer.yaml $(STAGING_DIR)

nginx_ingress:
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(NGINX_INGRESS_VERSION)/deploy/static/provider/cloud/deploy.yaml \
		-o $(STAGING_DIR)/ingress-nginx.yaml
	cp config/ingress-nginx/ingress-class.yaml $(STAGING_DIR)

tekton_pipelines:
	# https://github.com/tektoncd/pipeline/blob/master/docs/install.md
	curl -L https://storage.googleapis.com/tekton-releases/pipeline/previous/v$(TEKTON_PIPELINES_VERSION)/release.yaml \
		-o $(STAGING_DIR)/tekton-pipelines.yaml
	# https://github.com/tektoncd/dashboard/blob/master/docs/install.md
	curl -L  https://storage.googleapis.com/tekton-releases/dashboard/previous/v$(TEKTON_DASHBOARD_VERSION)/tekton-dashboard-release.yaml \
		-o $(STAGING_DIR)/tekton-dashboard.yaml
	cat config/tekton-pipelines/ingress.yaml \
		| sed 's/DOMAIN/$(DOMAIN)/g' > $(STAGING_DIR)/tekton-dashboard-ingress.yaml

lighthouse:
	helm template lighthouse \
		jenkins-x/lighthouse \
		--version $(LIGHTHOUSE_VERSION) \
		-n lighthouse \
		-f config/values/lighthouse.yaml \
		--set user=$(GITHUB_USERNAME) \
		--set tektoncontroller.dashboardURL=https://tekton.$(DOMAIN) \
		| sed "s/^metadata:.*/metadata:\n  namespace: lighthouse/g" \
		> $(STAGING_DIR)/lighthouse.yaml
	cp config/lighthouse/tekton-bot-service-account.yaml $(STAGING_DIR)
	cat config/lighthouse/ingress.yaml \
		| sed 's/DOMAIN/$(DOMAIN)/g' > $(STAGING_DIR)/lighthouse-hook-ingress.yaml
	cat config/lighthouse/config.yaml \
		| sed 's/DOMAIN/$(DOMAIN)/g' \
		| sed 's/GITHUB_OWNER/$(GITHUB_OWNER)/g' \
		| sed 's/GITHUB_REPOSITORY/$(GITHUB_REPOSITORY)/g' > $(STAGING_DIR)/config.yaml
	cat config/lighthouse/plugins.yaml \
		| sed 's/GITHUB_OWNER/$(GITHUB_OWNER)/g' \
		| sed 's/GITHUB_REPOSITORY/$(GITHUB_REPOSITORY)/g' > $(STAGING_DIR)/plugins.yaml

flux:
	helm template flux fluxcd/flux \
		--version $(FLUX_VERSION) \
		--set env.secretName=flux-git-auth \
		--set git.url='https://$$(GIT_AUTHUSER):$$(GIT_AUTHKEY)@github.com/$(GITHUB_OWNER)/$(GITHUB_REPOSITORY).git' \
		--set git.path=$(MANIFESTS_DIR) \
		--set git.pollInterval=1m \
		--set git.branch=main \
		--set registry.disableScanning=true \
		--set syncGarbageCollection.enabled=true \
		--namespace flux \
		| sed "s/^metadata:.*/metadata:\n  namespace: flux/g" \
		> $(STAGING_DIR)/flux.yaml

format:
	kfmt -i $(STAGING_DIR) -o $(MANIFESTS_DIR) \
		--create-missing-namespaces \
		-f Secret \
		-f Release.jenkins.io

post:
	rm -r $(STAGING_DIR)

docker_build:
	docker build \
		--build-arg HELM_VERSION=$(HELM_VERSION) \
		--build-arg KFMT_VERSION=$(KFMT_VERSION) \
		-t $(DOCKER_IMAGE) $(CURDIR)

docker_push: docker_build
	docker push $(DOCKER_IMAGE)

docker_%: docker_build
	docker run -it \
		-v $(CURDIR):/workspace \
		$(DOCKER_IMAGE) \
		make $*
