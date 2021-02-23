#!/bin/bash

set -euxo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ISTIO_TARGET_VERSION="$(istioctl version -o json | grep -v "no running Istio pods" | jq -r '.clientVersion.tag')"
ISTIO_TARGET_REVISION=$(echo "$ISTIO_TARGET_VERSION" | tr '.' '-')
ISTIO_EXISTING_VERSIONS=$(istioctl version -o json | grep -v "no running Istio pods" | jq -r '.meshVersion[]? | .Info.tag')

# Install target version
istioctl install -y \
  -f "$SCRIPT_DIR/istio-operator.yaml" \
  --set tag="$ISTIO_TARGET_VERSION" \
  --set revision="$ISTIO_TARGET_REVISION"

# Remove Namespaces
NAMESPACES=$(cat $SCRIPT_DIR/namespaces.txt)
ALL_NAMESPACES=$(kubectl get ns -l istio.io/rev --no-headers --ignore-not-found -o jsonpath='{.items[*].metadata.name}')
for NAMESPACE in $ALL_NAMESPACES; do
  if echo "$NAMESPACES" | grep "^$NAMESPACE$"; then
    continue
  fi
  kubectl label namespace "$NAMESPACE" istio.io/rev-
  # Roll Deployments
  DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers --ignore-not-found -o jsonpath='{.items[*].metadata.name}')
  for DEPLOYMENT in $DEPLOYMENTS; do
    kubectl rollout restart deployment -n "$NAMESPACE" "$DEPLOYMENT"
    kubectl rollout status deployment -n "$NAMESPACE" "$DEPLOYMENT"
  done
done

# Add Namespaces
for NAMESPACE in $NAMESPACES; do
  kubectl label namespace "$NAMESPACE" istio.io/rev="$ISTIO_TARGET_REVISION" --overwrite
  # Roll Deployments
  DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers --ignore-not-found -o jsonpath='{.items[*].metadata.name}')
  for DEPLOYMENT in $DEPLOYMENTS; do
    kubectl rollout restart deployment -n "$NAMESPACE" "$DEPLOYMENT"
    kubectl rollout status deployment -n "$NAMESPACE" "$DEPLOYMENT"
  done
done

# Uninstall previous version(s)
for ISTIO_VERSION in $ISTIO_EXISTING_VERSIONS; do
  if [ "$ISTIO_VERSION" = "$ISTIO_TARGET_VERSION" ]; then
    continue
  fi
  istioctl x uninstall -y --revision="$(echo "$ISTIO_VERSION" | tr '.' '-')"
done
