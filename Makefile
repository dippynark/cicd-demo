DOCKER_IMAGE = dippynark/cicd-demo:v1.0.0

KFMT_VERSION = 0.5.0
KUSTOMIZE_VERSION = 3.8.10
CLUSTERCTL_VERSION = 0.3.14
FLUX_VERSION = 0.9.0
KUBECTL_VERSION = 1.19

MANIFESTS = config/manifests

BOOKINFO_VERSION = release-1.9
# We can't use >0.16.1 since v1alpha2 is required for Cluster API
CERT_MANAGER_VERSION = 0.16.1
INGRESS_NGINX_VERSION = 0.44.0
TEKTON_PIPELINES_VERSION = 0.21.0
TEKTON_DASHBOARD_VERSION = 0.14.0
CLUSTER_API_VERSION = 0.3.14
CLUSTER_API_PROVIDER_KUBERNETES_VERSION = 0.3.5
CALICO_VERSION = 3.18

SHELL=/bin/bash -o pipefail

generate: bookinfo \
	calico \
	cert_manager \
	cluster_api \
	cluster_api_provider_kuberentes \
	infrastructure \
	ingress_nginx \
	tekton_pipelines

## Addons

bookinfo:
	rm -rf $(call base,bookinfo)
	curl -L https://raw.githubusercontent.com/istio/istio/$(BOOKINFO_VERSION)/samples/bookinfo/platform/kube/bookinfo.yaml \
		| kfmt -n bookinfo --create-missing-namespaces -o $(call base,bookinfo)/resources
	$(call kustomize,bookinfo)

calico:
	rm -rf $(call base,calico)
	curl -L https://docs.projectcalico.org/archive/v$(CALICO_VERSION)/manifests/calico.yaml \
		| kfmt -o $(call base,calico)/resources
	$(call kustomize,calico)

cert_manager:
	rm -rf $(call base,cert-manager)
	curl -L https://github.com/jetstack/cert-manager/releases/download/v$(CERT_MANAGER_VERSION)/cert-manager.yaml \
		| kfmt -i /dev/stdin -i $(MANIFESTS)/clusterissuer-letsencrypt.yaml -o $(call base,cert-manager)/resources
	$(call kustomize,cert-manager)

cluster_api:
	rm -rf $(call base,cluster-api)
	# Enable ClusterResourceSet
	# https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-resource-set.html
	# Unfortunately `clusterctl generate yaml` strips Namespace names from output manifests, so we perform variable substituion manually
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v$(CLUSTER_API_VERSION)/core-components.yaml | sed 's/$${EXP_CLUSTER_RESOURCE_SET:=false}/true/g; s/$${EXP_MACHINE_POOL:=false}/false/g' > core-components.yaml
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v$(CLUSTER_API_VERSION)/bootstrap-components.yaml | sed 's/$${EXP_MACHINE_POOL:=false}/false/g' > bootstrap-components.yaml
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v$(CLUSTER_API_VERSION)/control-plane-components.yaml | sed 's/$${EXP_MACHINE_POOL:=false}/false/g' > control-plane-components.yaml
	# Format
	kfmt -i core-components.yaml -i bootstrap-components.yaml -i control-plane-components.yaml \
		--gvk-scope Certificate.cert-manager.io/v1alpha2:Namespaced --gvk-scope Issuer.cert-manager.io/v1alpha2:Namespaced \
		--remove \
		-o $(call base,cluster-api)/resources
	$(call kustomize,cluster-api)

cluster_api_provider_kuberentes:
	rm -rf $(call base,cluster-api-provider-kuberentes)
	curl -L https://github.com/dippynark/cluster-api-provider-kubernetes/releases/download/v$(CLUSTER_API_PROVIDER_KUBERNETES_VERSION)/infrastructure-components.yaml | \
		kfmt --gvk-scope Certificate.cert-manager.io/v1alpha2:Namespaced --gvk-scope Issuer.cert-manager.io/v1alpha2:Namespaced \
			-o $(call base,cluster-api-provider-kuberentes)/resources
	$(call kustomize,cluster-api-provider-kuberentes)

infrastructure:
	curl -LO https://docs.projectcalico.org/archive/v$(CALICO_VERSION)/manifests/calico.yaml
	kubectl create configmap calico-addon -n infrastructure --from-file=calico.yaml --dry-run=client -o yaml > $(call base,infrastructure)/configmap-calico-addon.yaml
	rm calico.yaml

ingress_nginx:
	rm -rf $(call base,ingress-nginx)
	# https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(INGRESS_NGINX_VERSION)/deploy/static/provider/cloud/deploy.yaml \
		| kfmt -o $(call base,ingress-nginx)/resources
	$(call kustomize,ingress-nginx)

tekton_pipelines:
	rm -rf $(call base,tekton-pipelines)
	# https://github.com/tektoncd/pipeline/blob/master/docs/install.md
	curl -L https://storage.googleapis.com/tekton-releases/pipeline/previous/v$(TEKTON_PIPELINES_VERSION)/release.yaml \
		|	kfmt -o $(call base,tekton-pipelines)/resources
	# https://github.com/tektoncd/dashboard/blob/master/docs/install.md
	curl -L https://storage.googleapis.com/tekton-releases/dashboard/previous/v$(TEKTON_DASHBOARD_VERSION)/tekton-dashboard-release.yaml \
		|	kfmt -o $(call base,tekton-pipelines)/resources
	kfmt -i config/manifests/tekton-dashboard-ingress.yaml -o $(call base,tekton-pipelines)/resources
	$(call kustomize,tekton-pipelines)

## Infrastructure

.PHONY: clusters
clusters:
	rm -rf clusters/management/infrastructure
	mkdir -p clusters/management/infrastructure
	$(call add_cluster,clusters/management/infrastructure,development)
	$(call add_cluster,clusters/management/infrastructure,staging)

## Docker

docker_build:
	docker build \
		--build-arg KFMT_VERSION=$(KFMT_VERSION) \
		--build-arg KUSTOMIZE_VERSION=$(KUSTOMIZE_VERSION) \
		--build-arg CLUSTERCTL_VERSION=$(CLUSTERCTL_VERSION) \
		--build-arg FLUX_VERSION=$(FLUX_VERSION) \
		--build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) \
		-t $(DOCKER_IMAGE) $(CURDIR)

docker_push: docker_build
	docker push $(DOCKER_IMAGE)

docker_%: docker_build
	# https://stackoverflow.com/a/38754878/6180803
	docker run -it \
		-w /workspace \
		-v $(CURDIR):/workspace \
		-v $(HOME)/.kube:/root/.kube \
		$(DOCKER_IMAGE) \
		make $* $(MAKEOVERRIDES)

## Helpers

base = $(shell echo config/bases/$(1))

define kustomize
rm -f config/bases/$(1)/kustomization.yaml
touch config/bases/$(1)/kustomization.yaml
cd config/bases/$(1) && for resource in `find . -type f -name "*.yaml" | grep -v kustomization.yaml | sort`; do \
	kustomize edit add resource $$resource; \
done
endef

export WORKER_MACHINE_COUNT = 1
export CONTROL_PLANE_MACHINE_COUNT = 1
export KUBERNETES_CONTROL_PLANE_SERVICE_TYPE = LoadBalancer
export KUBERNETES_CONTROLLER_MACHINE_CPU_REQUEST = 500m
export KUBERNETES_CONTROLLER_MACHINE_MEMORY_REQUEST = 1Gi
export KUBERNETES_WORKER_MACHINE_CPU_REQUEST = 200m
export KUBERNETES_WORKER_MACHINE_MEMORY_REQUEST = 1Gi
export ETCD_STORAGE_CLASS_NAME = standard
export ETCD_STORAGE_SIZE = 1Gi
export KUBERNETES_VERSION = v1.17.17
define add_cluster
$(eval DIR=$(1))
$(eval NAME=$(2))
cd $(DIR) && touch kustomization.yaml
cd $(DIR) && clusterctl config cluster -n infrastructure $(NAME) --from https://github.com/dippynark/cluster-api-provider-kubernetes/blob/v$(CLUSTER_API_PROVIDER_KUBERNETES_VERSION)/release/cluster-template-persistent-control-plane.yaml > $(NAME)-cluster.yaml
cd $(DIR) && kustomize edit add resource $(NAME)-cluster.yaml
endef

get_kubeconfig_%:
	kubectl get secret -n infrastructure $*-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > kubeconfig

promote:
	./hack/promote.sh $(SOURCE) $(DESTINATION)
