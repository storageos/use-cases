#!/bin/bash
set -euo pipefail

# 
# The following script provisions a remote volume with no replicas and runs fio tests
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

echo -e "${GREEN}Scenario: Remote Volume with no replica${NC}"
echo

# Checking if jq is in the PATH
if ! command -v jq &> /dev/null
then
    echo "${RED}jq could not be found. Please install jq and run the script again${NC}"
    exit
fi

# Get the node name and id where the volume will get provisioned and attached on
# Using the StorageOS cli is guarantee that the node is running StorageOS
node_details=$(kubectl -n kube-system exec cli -- storageos describe nodes -ojson | jq -r '[.[0].labels."kubernetes.io/hostname",.[0].id,.[1].labels."kubernetes.io/hostname",.[1].id]')
node_id=$(echo $node_details | jq -r '.[1]')
node_name=$(echo $node_details | jq -r '.[0]')
node_id1=$(echo $node_details | jq -r '.[3]')
node_name1=$(echo $node_details | jq -r '.[4]')

pvc_prefix="$RANDOM"
manifest_path="./tmp-remote-fio"
fio_job="remote-volume-no-replica-fio"
manifest="${manifest_path}/${fio_job}.yaml"
logs_path="./tmp-fio-logs"


if [ -d "$manifest_path" ]; then
    rm -rf "$manifest_path"
fi

# Create a temporary dir where the dbench.yaml will get created in
mkdir -p $manifest_path

[ ! -d "${logs_path}" ] && mkdir -p ${logs_path}

# Create a 25 Gib StorageOS volume with no replicas manifest
cat <<END >> $manifest
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-${pvc_prefix}
  labels:
    storageos.com/hint.master: "${node_id1}"
spec:
  storageClassName: fast
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 15Gi
---
END

# Create batch job for the FIO tests manifest
cat <<END >> $manifest
apiVersion: batch/v1
kind: Job
metadata:
  name: "${fio_job}"
spec:
  template:
    spec:
      nodeSelector:
        "kubernetes.io/hostname": ${node_name}
      containers:
      - name: "${fio_job}"
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

# echo -e "${GREEN}FIO Job Manifest created and can be found under ${manifest_path}${NC}"
# echo -e "${GREEN}Deploy the remote-volume-fio:${NC}"
# echo -e "kubectl create -f ${manifest}"
# echo -e "${GREEN}Deploy the remote-volume-fio:${NC}"
# echo -e "${GREEN}Follow benchmarking progress using:${NC}"
# echo -e "kubectl logs -f job/remote-volume-fio"
# echo -e "${GREEN}Once the tests are finished, clean up using:${NC}"
# echo -e "kubectl delete -f ${manifest}"
# echo -e "rm -rf ${manifest_path}"
# echo

kubectl create -f ${manifest}

echo -e "${GREEN}Waiting for the ${fio_job} Job to finish.${NC}"
echo -e "${GREEN}This can take up to 5 minutes${NC}"

sleep 5
pod=$(kubectl get pod -l job-name=${fio_job} --no-headers -ocustom-columns=_:.metadata.name 2>/dev/null || :)
SECONDS=0
TIMEOUT=180
while ! kubectl get pod ${pod} -otemplate="{{ .status.phase }}" 2>/dev/null| grep -q Succeeded; do
  pod_status=$(kubectl get pod ${pod} -otemplate="{{ .status.phase }}" 2>/dev/null)
  # >&2 echo "DEBUG: `date` Pod: ${pod} Status: ${pod_status}"
  if [ $SECONDS -gt $TIMEOUT ]; then
      echo "The pod $pod didn't succeed after $TIMEOUT seconds" 1>&2
      echo -e "${GREEN}Pod: ${pod}, is in ${pod_status}${NC} state."
      exit 1
  fi
done

pod_status=$(kubectl get pod ${pod} -otemplate="{{ .status.phase }}" 2>/dev/null)
echo -e "${GREEN}Pod: ${pod}, ${pod_status}${NC}"

kubectl logs -f jobs/${fio_job} > ${logs_path}/local-volume-with-replica-fio.log
tail -n 7 ${logs_path}/local-volume-with-replica-fio.log
kubectl delete -f ${manifest}