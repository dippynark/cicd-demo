#!/bin/bash

set -euo pipefail

SOURCE_CLUSTER=$1
DESTINATION_CLUSTER=$2

# Check existance of source cluster sync config
SOURCE_CLUSTER_SYNC=clusters/$SOURCE_CLUSTER/flux-system/cluster-sync.yaml
if [ ! -f "$SOURCE_CLUSTER_SYNC" ]; then
  echo $SOURCE_CLUSTER_SYNC does not exist
  exit 1
fi

# Ensure destination cluster sync config exists and is registered with kustomization
DESTINATION_CLUSTER_SYNC=clusters/$DESTINATION_CLUSTER/flux-system/cluster-sync.yaml
if [ ! -f "$DESTINATION_CLUSTER_SYNC" ]; then
  cp -a $SOURCE_CLUSTER_SYNC $DESTINATION_CLUSTER_SYNC
  (cd $(dirname $DESTINATION_CLUSTER_SYNC) && kustomize edit add resource $(basename $DESTINATION_CLUSTER_SYNC))
fi

# Retrieve source branch and path
SOURCE_BRANCH=$(cat $SOURCE_CLUSTER_SYNC | grep branch: | head -n 1 | awk '{print $2}')
SOURCE_PATH=$(cat $SOURCE_CLUSTER_SYNC | grep path: | head -n 1 | awk '{print $2}')

# Replace main branch with fixed tag
if [ $SOURCE_BRANCH = main ] || [ $SOURCE_BRANCH = master ]; then
  SOURCE_BRANCH=$(git describe --tags --always $SOURCE_BRANCH)
fi

# Replace source values in destination
sed -i -r "s/^    branch: .*/    branch: $SOURCE_BRANCH/" $DESTINATION_CLUSTER_SYNC
sed -i -r "s#^  path: .*#  path: $SOURCE_PATH#1" $DESTINATION_CLUSTER_SYNC
