#!/bin/bash
set -euo pipefail

#
#
# In order to successfully execute the synthetic benchmarks you will need to have:
#  - Kubernetes cluster with a minium of 3 nodes and 30 Gib space
#  - kubectl in the PATH - kubectl access to this cluster with
#    cluster-admin privileges - export KUBECONFIG as appropriate
#  - StorageOS CLI running as a pod in the cluster
#  - jq in the PATH
# 
# The following script ---- runs fio tests
# to measure StorageOS performance. The FIO tests that are run can be found
# here: https://github.com/storageos/dbench/blob/master/docker-entrypoint.sh
# 
#
#

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Welcome to the StorageOS quick FIO job generator script${NC}"
echo -e "${GREEN}I'll now run the following 4 scenarios and show you the results for each scenario at the end!${NC}"
echo

# Execute dbench-job-generator-local-volume.sh script
# ./local-volumes/dbench-job-generator-local-volume.sh

# # Execute dbench-job-generator-local-volume-replica.sh script
# ./local-volumes/dbench-job-generator-local-volume-replica.sh

./remote-local-volumes/dbench-job-generator-remote-volume.sh

./remote-local-volumes/dbench-job-generator-remote-volume-replica.sh