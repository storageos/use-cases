# Using velero to backup your StorageOS volumes

Velero is an open source tool to safely backup and restore, perform disaster recovery, and migrate Kubernetes cluster resources and persistent volumes.

Velero consists of the following components:
1. A velero Server in the cluster
1. A CLI client
1. A restic daemonset in the cluster

In our case, we will use MinIO in the Kubernetes cluster as the "cloud
provider" pictured in the backup diagram. MinIO is an object store that uses
an S3 compatible API and as such can be used to store our backed up resources.

We will set up MinIO through a StatefulSet with a 50GiB StorageOS volume and a
ClusterIP service. The UI can be accessed through the browser by port-forwarding the
MinIO service.

Velero uses Restic to backup Kubernetes volumes. Restic is a fast and secure
backup program for filesystems whose documentation can be found
[here](https://restic.readthedocs.io/en/latest/100_references.html). The way it
works is that it scans the volume directory for its files and then splits those
files into blobs which are then sent to MinIO.
[Here's](https://Velero.io/docs/main/restic/) how it integrates with Velero.

## Prerequisites

Here are the prerequisites for running Velero in your Kubernetes cluster:

1. Kubernetes cluster version 1.13+ with DNS
1. Kubectl installed
1. Velero cli installed https://Velero.io/docs/main/basic-install/
> Velero can also be installed from a helm chart

## Install MinIO with a StorageOS volume

1. First, make sure to clone the StorageOS use cases repository and navigate to
the Velero directory:

    ```bash 
    git clone https://github.com/storageos/use-cases.git 
    cd use-cases/Velero
    ```

1. Installing MinIO is really simple, just deploy it using the
`minio-deploy.yaml` manifest file:

    ```bash
    kubectl apply ./minio
    ```

1. Confirm that MinIO was deployed successfully:

    ```bash
    $ kubectl get pods -n velero
    NAME                      READY   STATUS      RESTARTS   AGE
    minio-0                   1/1     Running     0          3m48s
    minio-setup-zvcdg         0/1     Completed   1          3m47s

    ```

    You can access the web UI of MinIO by port-forwarding the MinIO service
    with this command:

    ```bash
    kubectl port-forward service/minio -n velero 9000
    ```

## Install Velero

Use the following command to install Velero via the Velero CLI or alternatively
use the helm chart. To install it using the Velero cli, just run this command:

> The AWS plugin is being used because MinIO implements the S3 API. This is
> required even if you're not using AWS.

```bash 
velero install                                                                                   \
--provider aws                                                                                   \
--plugins velero/velero-plugin-for-aws:v1.0.0                                                    \
--bucket velero                                                                                  \
--secret-file ./credentials-Velero                                                               \
--use-volume-snapshots=false                                                                     \
--backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000 \
--use-restic
```

Make sure that Velero is installed correctly:

```bash
$ kubectl logs deployment/velero -n velero
...
time="2020-08-25T15:33:09Z" level=info msg="Server started successfully" logSource="pkg/cmd/server/server.go:881"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=restic-repository logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=restore logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=backup-sync logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=backup logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=backup-deletion logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Checking for expired DeleteBackupRequests" controller=backup-deletion logSource="pkg/controller/backup_deletion_controller.go:551"
time="2020-08-25T15:33:09Z" level=info msg="Done checking for expired DeleteBackupRequests" controller=backup-deletion logSource="pkg/controller/backup_deletion_controller.go:579"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=schedule logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=downloadrequest logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=gc-controller logSource="pkg/controller/generic_controller.go:76"
time="2020-08-25T15:33:09Z" level=info msg="Starting controller" controller=serverstatusrequest logSource="pkg/controller/generic_controller.go:76"
```

## Simple Debian pod use case

For the first use case, we'll just use a simple debian pod.

1. Deploy the debian pod and its PVC:

    ```bash
    kubectl apply -f ./debian
    ```

1. Create a file with 'Hello World' in the pod.

    ```bash
    $ kubectl exec -it d1 -n debian -- sh -c 'echo Hello World! > /mnt/hello'
    $ kubectl exec -it d1 -n debian -- cat /mnt/hello
    Hello World!
    ```

1. Annotate pod to mark its volume for backup. This is needed for Restic to
know which volume to backup:

    ```bash
    kubectl annotate pod/d1 -n debian backup.Velero.io/backup-volumes=v1 
    ```

1. Create a backup with Velero:

    ```bash
    velero backup create debian-backup --include-namespaces debian --wait
    ```

1. Confirm that all the Kubernetes objects are there and the Restic backups
completed successfully:

    ```bash
    velero backup describe debian-backup --details
    ```

1. Delete the pod and PVC:

    ```bash
    kubectl delete pod d1 -n debian
    kubectl delete pvc pvc-1 -n debian
    ```

1. Restore the pod using Velero:

    ```bash
    velero restore create --from-backup debian-backup --wait
    ```

1. Confirm that the hello world file has been restored:

    ```bash
    $ kubectl exec -it d1 -n debian -- cat /mnt/hello
    Hello World!
    ```

The pod was restored successfully!

## MySQL use case

For the second use case, we'll use Velero with a real world application, MySQL.

1. First deploy MySQL, based on the MySQL use case:

    ```bash 
    kubectl apply -f ./mysql 
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

    The first annotation specifies which volume to backup using restic. The other
    annotations are used to perform an fsfreeze on the volume mount point using pre
    and post backup hooks, for more details about Velero pre/post backup hooks
    please see their documentation [here](https://Velero.io/docs/main/hooks/).

    We have to specify to use the `fsfreeze` ubuntu container since the MySQL
    container doesn't support fsfreeze

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
    $ kubectl get pods -n mysql
    NAME      READY   STATUS    RESTARTS   AGE
    client    1/1     Running   0          24m
    mysql-0   2/2     Running   0          24m
    ```

1. Exec into the MySQL pod and populate it with data using the commands below.

    ```bash 
    $ kubectl exec mysql-0 -n mysql -ti -c mysql -- mysql
    mysql> create database shop;
    mysql> use shop;
    mysql> create table books (title VARCHAR(256), price decimal(4,2));
    mysql> insert into books value ('Gates of Fire', 13.99);
    mysql> select * from books;
    +---------------+-------+
    | title         | price |
    +---------------+-------+
    | Gates of Fire | 13.99 |
    +---------------+-------+
    1 row in set (0.00 sec)
    mysql> exit
    ```

1. Create the Velero backup:

    ```bash 
    velero backup create mysql-backup --include-namespaces mysql --wait
    ```

1. Confirm that all the Kubernetes objects are there and the restic backups
completed successfully:

    ```bash 
    velero backup describe mysql-backup --details
    ```

1. After the backup is finished, delete the StatefulSet and PVC.

    > N.B. It's important to make sure that the StatefulSet is deleted because the
    > restore would be unable to complete if a StatefulSet pod is recreated during
    > the restore process.

    ```bash 
    kubectl delete statefulset mysql -n mysql
    kubectl delete pvc data-mysql-0 -n mysql
    ```

1. Make sure that the pod is fully terminated:

    ```bash 
    $ kubectl get pods -n mysql
    NAME     READY   STATUS    RESTARTS   AGE
    client   1/1     Running   0          25m
    ```

1. Restore MySQL using Velero:

    ```bash
    velero restore create --from-backup mysql-backup --wait
    ```

1. Wait for the MySQL pod to spin up and see if the data is backed up:

    ```bash
    $ kubectl exec mysql-0 -n mysql -ti -c mysql -- mysql 
    mysql> use shop; 
    mysql> select * from books;
    +---------------+-------+
    | title         | price |
    +---------------+-------+
    | Gates of Fire | 13.99 |
    +---------------+-------+
    1 row in set (0.00 sec)
    mysql> exit
    ```

The data should be there and the backup was restored successfully!
