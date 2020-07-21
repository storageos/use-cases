#!/bin/bash
set -euo pipefail

#
# The following script provisions a local volume with no replicas and runs fio tests
# to measure StorageOS performance. The FIO tests that are run can be found
# here: https://github.com/storageos/dbench/blob/master/docker-entrypoint.sh
#
# In order to successfully execute the tests you will need to have:
#  - Kubernetes cluster with a minium of 3 nodes and 30 Gib space
#  - kubectl in the PATH - kubectl access to this cluster with
#    cluster-admin privileges - export KUBECONFIG as appropriate
#  - StorageOS CLI running as a pod in the cluster
#  - jq in the PATH 
#

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


echo -e "${GREEN}Welcome to the StorageOS quick FIO job generator script for a local volume with no replicas${NC}"
echo

# Checking if jq is in the PATH
if ! command -v jq &> /dev/null
then
    echo "${RED}jq could not be found. Please install jq and run the script again${NC}"
    exit
fi

# Get the node name and id where the volume will get provisioned and attached on
# Using the StorageOS cli is guarantee that the node is running StorageOS
node_details=$(kubectl -n kube-system exec cli -- storageos describe nodes -o json | jq -r '[.[0].labels."kubernetes.io/hostname",.[0].id]')
# The ID of the 1st node in the cluster
node_id=$(echo $node_details | jq -r '.[1]')
# The Name of the 1st node in the cluster
node_name=$(echo $node_details | jq -r '.[0]')
pvc_prefix="$RANDOM"
manifest_path="./tmp-local-fio"
manifest="${manifest_path}/dbench.yaml"

if [ -f "$manifest" ]; then
    rm -rf "$manifest"
fi

# Create a temporary dir where the dbench.yaml will get created in
mkdir -p $manifest_path

# Create a 25 Gib StorageOS volume with no replicas manifest
cat <<END >> $manifest
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-${pvc_prefix}
  labels:
    storageos.com/hint.master: "${node_id}"
spec:
  storageClassName: fast
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 25Gi
---
END

# Create batch job for the FIO tests manifest
cat <<END >> $manifest
apiVersion: batch/v1
kind: Job
metadata:
  name: local-volume-fio
spec:
  template:
    spec:
      containers:
      - name: local-volume-fio
        image: storageos/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: pvc-${pvc_prefix}
  backoffLimit: 4
END

echo -e "${GREEN}FIO Job Manifest created and can be found under ${manifest_path}${NC}"
echo -e "${GREEN}Deploy the local-volume-fio:${NC}"
echo -e "kubectl create -f ${manifest}"
echo -e "${GREEN}Deploy the local-volume-fio:${NC}"
echo -e "${GREEN}Follow benchmarking progress using:${NC}"
echo -e "kubectl logs -f job/local-volume-fio"
echo -e "${GREEN}Once the tests are finished, clean up using:${NC}"
echo -e "kubectl delete -f ${manifest}"
echo -e "rm -rf ${manifest}"
echo
