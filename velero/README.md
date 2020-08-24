# Using velero to backup your StorageOS volumes

Velero is an open source tool to safely backup and restore, perform disaster recovery, and migrate Kubernetes cluster resources and persistent volumes.

Velero consists of the following components:
1. A velero Server on the cluster
1. A CLI client
1. A restic daemonset on the cluster

In our case, we will use Minio in the Kubernetes cluster as the "cloud provider". Minio is an object store that uses the s3 API and as such can be used as our "cloud provider".

We will set up Minio through a StatefulSet with a 10GiB StorageOS volume and a NodePort service. I included 2 services in the manifest, a ClusterIP and a NodePort. Using the NodePort, the UI can be accessed with a browser.

Velero uses restic to backup Kubernetes volumes. Restic is a fast and secure backup program for file-systems whose documentation can be found [here](https://restic.readthedocs.io/en/latest/100_references.html). The way it works is that it scans the volume directory for its files and then splits those files into blobs which are then sent to minio. [Here's](https://velero.io/docs/main/restic/) how it integrates with Velero.

# Prerequisites

Here's the prerequisites for running velero in your Kubernetes cluster:

1. Kubernetes cluster version 1.10+ with DNS
1. kubectl installed
1. Velero cli installed https://Velero.io/docs/main/basic-install/
    1. Velero can also be installed from a helm chart

# Install Minio with a StorageOS volume

Installing Minio is really simple, just deploy it using the `minio-deploy.yaml` manifest file:

```bash
kubectl apply minio-deploy.yaml
```

Confirm that Minio has deployed successfully:

```bash
kubectl get pods -n velero
```

You can also access the web UI of Minio using the node port.

# Install Velero

As mentioned earlier, velero can be install either with the velero cli or a helm chart. To install it using the velero cli, just run this command:

```bash
velero install \                                      
     --provider aws \
     --plugins velero/velero-plugin-for-aws:v1.0.0 \
     --bucket velero \
     --secret-file ./credentials-velero \
     --use-volume-snapshots=false \
     --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000 \
     --use-restic
```

Make sure that velero is installed correctly:

```bash
kubectl logs deployment/velero -n velero
```

# Simple Debian pod use case

For the first use case, we'll just use a simple debian pod.

1. Deploy the debian pod and its PVC:

```bash
kubectl apply -f debian
```

1. Create a file with 'Hello World' in the pod.

```bash
kubectl exec -it d1 -- echo Hello World! > /mnt/hello
kubectl exec -it d1 -- cat /mnt/hello
```

1. Annotate pod to mark its volume for backup. This is need for restic to know which volume to backup:

```bash
kubectl annotate pod/replicated-pod backup.velero.io/backup-volumes=v1
```

1. Create a backup with Velero:

```bash
velero backup create debian-backup --include-namespaces debian --wait
```

1. Confirm that all the Kubernetes objects are there and the restic backups completed successfully:

```bash
velero backup describe debian-backup --details
```

1. Delete the pod and PVC:

```bash
kubectl delete pod d1
kubectl delete pvc pvc-1
```

1. Restore the pod using Velero:

```bash
velero restore create --from-backup debian-backup --wait
```

1. Confirm that the hello world file is still in the pod:

```bash
kubectl exec -it d1 -- cat /mnt/hello
```

The pod was restored successfully!

# Mysql use case

For the second use case, we'll use velero with a real world application, mysql.

1. First deploy mysql, based on the mysql use case:

```bash
kubectl apply -f mysql
```

Notice that the Statefulset also includes 5 annotations:

```yaml
annotations:
    backup.velero.io/backup-volumes: data
    pre.hook.backup.velero.io/command: '["/sbin/fsfreeze", "--freeze", "/var/lib/mysql"]'
    pre.hook.backup.velero.io/container: fsfreeze
    post.hook.backup.velero.io/command: '["/sbin/fsfreeze", "--unfreeze", "/var/lib/mysql"]'
    post.hook.backup.velero.io/container: fsfreeze
```

The first one is used to identify which volume to backup using restic, like we saw above. The rest do an fsfreeze on the volume mount point using the pre and post backup hook commands of velero, more details can be found [here](https://velero.io/docs/main/hooks/).

There's also an fsfreeze ubuntu container since the mysql container doesn't support fsfreeze:

```yaml
- name: fsfreeze
  image: ubuntu:bionic
  securityContext:
    privileged: true
  volumeMounts:
    - name: data
      mountPath: /var/lib/mysql
  command:
    - "/bin/bash"
    - "-c"
    - "sleep infinity"
```

1. Wait for the pod to spin up:

```bash
kubectl get pods -n mysql
```

1. Exec into the mysql pod and populate it with data using the `example.sql` file.

```bash
kubectl exec mysql-0 -n mysql -ti -c mysql -- mysql
create database shop;
use shop;
create table books (title VARCHAR(256), price decimal(4,2));
insert into books value ('Gates of Fire', 13.99);
select * from books;
```
1. Create the velero backup:

```bash
velero backup create mysql-backup --include-namespaces mysql --wait
```

1. Confirm that all the Kubernetes objects are there and the restic backups completed successfully:

```bash
velero backup describe mysql-backup --details
```

1. After the backup is finished, delete the StatefulSet and PVC. NOTE: It's important to make sure that the overarching deployment/StatefulSet is deleted because the restore would be incomplete if the pod starts spinning up during the process.

```bash
kubectl delete statefulset mysql
kubectl delete pvc data-mysql-0
```

1. Make sure that the pod is fully terminated:

```bash
kubectl get pods -n mysql
```

1. Restore mysql using velero:

```bash
velero restore create --from-backup mysql-backup
```

1. Wait for the mysql pod to spin up and see if the data is backed up:

```bash
kubectl exec mysql-0 -n mysql -ti -c mysql -- mysql
use shop;
select * from books;
```

The data should be there and the backup was restored successfully!