#!/bin/bash

if [ -z "$1" ]; then
    echo "Number of volumes not defined."
    exit 1
fi

if [ -z "$2" ]; then
    echo "Node not defined (pod nodeSelector)"
fi

if [ -z "$3" ]; then
    echo "StorageOS node not defined (volume hint, nodeSelector)"
fi


num_vols="$1"
node="$2"
stos_node="$3"
pvc_prefix="$RANDOM"
profile="profile-${num_vols}vol.fio"
manifest="./jobs/fio-${num_vols}vol.yaml"

if [ -f "$manifest" ]; then
    rm -f "$manifest"
fi

for v in $(seq 0 $((--num_vols))); do
    cat <<END >> $manifest
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-${pvc_prefix}-$v
  labels:
    storageos.com/hint.master: "$stos_node"
spec:
  storageClassName: fast
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
END

done


cat <<END >> $manifest
apiVersion: batch/v1
kind: Job
metadata:
  name: fio-${num_vols}vol
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: fio
        image: storageos/docker-fio:1.0.0
        command:
          - "fio"
          - "/tmp/$profile"
        volumeMounts:
          - name: fio-conf
            mountPath: /tmp/
END

for v in $(seq 0 $((--num_vols))); do
    cat <<END >> $manifest
          - name: vol$v
            mountPath: /mnt/pvc$v
END

done

cat <<"END" >> $manifest
        resources:
          requests:
            cpu: 500m
      volumes:
      - name: fio-conf
        configMap:
          name: fio-profiles-local
END


for v in $(seq 0 $((--num_vols))); do
    cat <<END >> $manifest
      - name: vol$v
        persistentVolumeClaim:
          claimName: pvc-${pvc_prefix}-$v
END

done


cat <<END > ./profiles/$profile
[global]
size=1GB
runtime=900
time_based=1
ioengine=libaio
direct=1
random_generator=tausworthe
random_distribution=random
rw=randrw
rwmixread=60
rwmixwrite=40
percentage_random=85
bs=4k
iodepth=64
log_avg_msec=250
group_reporting=1
END

for v in $(seq 0 $((--num_vols))); do
    cat <<END >>  ./profiles/$profile

[vol$v]
filename=/mnt/pvc$v/fio.dat
END

done

