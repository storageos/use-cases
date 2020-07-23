#!/bin/bash
set -euo pipefail

# StorageOS Self-Evaluation. 
# This script will execute the synthetic benchmarks on four StorageOS Volumes
# with different configurations to measure StorageOS performance.
# The FIO tests that are run can be found
# here: https://github.com/storageos/dbench/blob/master/docker-entrypoint.sh
#
# In order to successfully execute the synthetic benchmarks you will need to have:
#  - Kubernetes cluster with a minium of 3 nodes and minimum 30 Gib space
#  - kubectl in the PATH - kubectl access to this cluster with
#    cluster-admin privileges - export KUBECONFIG as appropriate
#  - StorageOS CLI running as a pod in the cluster
#  - jq in the PATH
#

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Welcome to the StorageOS quick FIO job generator script${NC}"
echo -e "${GREEN}I'll now run four scenarios to measure StoregeOS performance${NC}"
echo -e "${GREEN}and print the results for each scenario out!${NC}"
echo

# Clone the use-case repositories
echo -e "${GREEN}Clonining the StorageOS use-case repo in /tmp/storageos-usecases${NC}"
git clone https://github.com/storageos/use-cases.git /tmp/storageos-usecases

cd storageos-benchmarks/FIO/

# Scenario: Local Volume with no replicas
./local-volumes/dbench-job-generator-local-volume.sh
echo

# Scenario: Local Volume with a replica
./local-volumes/dbench-job-generator-local-volume-replica.sh
echo

# Scenario: Remote Volume without replicas
./remote-local-volumes/dbench-job-generator-remote-volume.sh
echo

# Scenario: Remote Volume with a replica
./remote-local-volumes/dbench-job-generator-remote-volume-replica.sh

echo -e "${GREEN}Cleanup files:${NC}"
echo -e "${GREEN}rm -rf /tmp/storageos-usecases${NC}"