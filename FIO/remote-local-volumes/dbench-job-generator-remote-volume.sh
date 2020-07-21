#!/bin/bash

# Requires the StorageOS CLI as a pod in kube-system

node_details=$(kubectl -n kube-system exec cli -- storageos describe nodes -ojson | jq -r '[.[0].labels."kubernetes.io/hostname",.[0].id,.[1].labels."kubernetes.io/hostname",.[1].id]')
node_id=$(echo $node_details | jq -r '.[1]')
node_name=$(echo $node_details | jq -r '.[0]')
node_id1=$(echo $node_details | jq -r '.[3]')
node_name1=$(echo $node_details | jq -r '.[4]')

pvc_prefix="$RANDOM"
manifest="./jobs/dbench.yaml"

if [ -f "$manifest" ]; then
    rm -f "$manifest"
fi

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
      storage: 25Gi
---
END

cat <<END >> $manifest
apiVersion: batch/v1
kind: Job
metadata:
  name: remote-volume-fio
spec:
  template:
    spec:
      nodeSelector:
        "kubernetes.io/hostname": ${node_name}
      containers:
      - name: remote-volume-fio
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
