ifndef CACHE_DIR
$(error CACHE_DIR is undefined)
endif

ifndef STAGING_DIR
$(error STAGING_DIR is undefined)
endif

ifndef MANIFESTS_DIR
$(error STAGING_DIR is undefined)
endif

setup:
	rm -rf $(STAGING_DIR) $(MANIFESTS_DIR)
	mkdir -p $(STAGING_DIR) $(MANIFESTS_DIR)

teardown:
	rm -r $(STAGING_DIR)

format:
	kfmt -i $(STAGING_DIR) -o $(MANIFESTS_DIR) \
		--create-missing-namespaces \
		-f Secret

cert_manager:
ifndef CERT_MANAGER_VERSION
	$(error CERT_MANAGER_VERSION is undefined)
endif
	curl -L https://github.com/jetstack/cert-manager/releases/download/v$(CERT_MANAGER_VERSION)/cert-manager.yaml \
		-o $(STAGING_DIR)/cert-manager.yaml

ingress_nginx:
ifndef INGRESS_NGINX_VERSION
	$(error NGINX_INGRESS_VERSION is undefined)
endif
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(INGRESS_NGINX_VERSION)/deploy/static/provider/cloud/deploy.yaml \
		-o $(STAGING_DIR)/ingress-nginx.yaml

tekton_pipelines:
ifndef TEKTON_PIPELINES_VERSION
	$(error TEKTON_PIPELINES_VERSION is undefined)
endif
	# https://github.com/tektoncd/pipeline/blob/master/docs/install.md
	curl -L https://storage.googleapis.com/tekton-releases/pipeline/previous/v$(TEKTON_PIPELINES_VERSION)/release.yaml \
		-o $(STAGING_DIR)/tekton-pipelines.yaml

tekton_dashboard:
ifndef TEKTON_DASHBOARD_VERSION
	$(error TEKTON_DASHBOARD_VERSION is undefined)
endif
	# https://github.com/tektoncd/dashboard/blob/master/docs/install.md
	curl -L https://storage.googleapis.com/tekton-releases/dashboard/previous/v$(TEKTON_DASHBOARD_VERSION)/tekton-dashboard-release.yaml \
		-o $(STAGING_DIR)/tekton-dashboard.yaml

bookinfo:
ifndef BOOKINFO_VERSION
	$(error BOOKINFO_VERSION is undefined)
endif
	curl -L https://raw.githubusercontent.com/istio/istio/$(BOOKINFO_VERSION)/samples/bookinfo/platform/kube/bookinfo.yaml \
		| sed "s/^metadata:.*/metadata:\n  namespace: bookinfo/g" \
		> $(STAGING_DIR)/bookinfo.yaml

lighthouse:
ifndef LIGHTHOUSE_VERSION
	$(error LIGHTHOUSE_VERSION is undefined)
endif
	$(call helm_fetch,lighthouse,$(LIGHTHOUSE_VERSION),http://chartmuseum.jenkins-x.io)
	$(call helm_template,lighthouse,$(LIGHTHOUSE_VERSION),lighthouse)
	# Manually add namespace field since this is not templated by the chart
	sed -i "s/^metadata:.*/metadata:\n  namespace: lighthouse/g" $(STAGING_DIR)/lighthouse.yaml

flux:
ifndef FLUX_VERSION
	$(error FLUX_VERSION is undefined)
endif
	$(call helm_fetch,flux,$(FLUX_VERSION),https://charts.fluxcd.io)
	$(call helm_template,flux,$(FLUX_VERSION),flux)

# Helper Functions
define helm_fetch
$(eval NAME=$(1))
$(eval VERSION=$(2))
$(eval REPO=$(3))
ls $(CACHE_DIR)/$(NAME)-$(VERSION)/$(NAME) || \
	helm fetch \
		-d $(CACHE_DIR) \
		--untar \
		--untardir $(NAME)-$(VERSION) \
		--repo $(REPO) \
		--version $(VERSION) \
		$(NAME)
endef

define helm_template
$(eval NAME=$(1))
$(eval VERSION=$(2))
$(eval NAMESPACE=$(3))
helm template $(NAME) ./$(CACHE_DIR)/$(NAME)-$(VERSION)/$(NAME) \
	-n $(NAMESPACE) \
	-f values/$(NAME).yaml \
	> $(STAGING_DIR)/$(NAME).yaml
endef
