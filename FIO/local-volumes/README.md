# Create jobs

## StorageOS FIO tests

The script `job-generator-per-volumecount.sh` takes an argument for the number
of concurrent volumes to be used in the test and an argument for the name of
the node where the volumes and pods will attempt to be allocated.

### Tests suggested

1. Get the node name where the volumes and the Pod should be collocated.

```bash
kubectl get node --show-labels
```

> The Node name and the label `kubernetes.io/hostname` have to match.

> The Node selected must have enough capacity to host all the volumes
> created for the test.

Get the StorageOS node ID for the same node - e846e605-d1c8-4d44-82bf-f6ba8080ece3 in the output below

```bash
storageos describe node $NODE
ID                                      e846e605-d1c8-4d44-82bf-f6ba8080ece3
Name                                    kind-worker2
Health                                  online
Addresses:
  Data Transfer address                 10.61.0.13:5703
  Gossip address                        10.61.0.13:5711
  Supervisor address                    10.61.0.13:5704
  Clustering address                    10.61.0.13:5710
Labels                                  beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=...
Created at                              2020-03-30T15:51:27Z (2 hours ago)
Updated at                              2020-03-30T15:56:37Z (2 hours ago)
Version                                 MQ
Available capacity                      490 MiB/9.8 GiB (8.8 GiB in use)

Local volume deployments:
  DEPLOYMENT ID                         VOLUME                                                                            NAMESPACE  HEALTH  TYPE    SIZE
  4a109049-f26d-4e7d-bdd4-22f4657aa1cb  pvc-ae11774d-a4b2-4a21-83e9-695c17e8ca6a                                          default    online  master  2.0 GiB
```

2. Generate tests (4, 8, 16 and 32 volumes)


```bash
~$ ./job-generator-per-volumecount.sh 4  $NODE_NAME1 $STOS_NODE_ID
~$ ./job-generator-per-volumecount.sh 8  $NODE_NAME2 $STOS_NODE_ID
~$ ./job-generator-per-volumecount.sh 16 $NODE_NAME3 $STOS_NODE_ID
~$ ./job-generator-per-volumecount.sh 32 $NODE_NAME4 $STOS_NODE_ID
```

The Job Generator creates a Job in `./jobs/` for each execution and its
according FIO profile file `./profiles/`. You can change the size of the
volumes by editing the ./jobs file.

3. Upload FIO profiles as ConfigMaps

```bash
~$ ./upload-fio-profiles.sh
```

The uploader creates a ConfigMap with all the FIO config files that will be
injected into the Job.

4. Run the tests

```bash
~$ kubectl create -f ./jobs/$JOB.yaml

```

5. Check the provisioning

```bash
~$ # Check that all the PVCs are provisioned 
~$ kubectl get pvc

# Use StorageOS CLI to verify where the volumes are collocated

# As a binary
~$ storageos get volumes 


# As a container
~$ kubectl -n storageos exec cli -- storageos get volumes


# Verify that the Pod is running in the same Node
~$ kubectl get pod -owide
```

6. Get the FIO results

```bash
~$ kubectl logs $POD
```


## DBench FIO Tests

### Local Volume with no replicas

The script `dbench-job-generator-local-volume.sh` provisions a StorageOS Volume
and a Pod on the same node and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance. It requires
the StorageOS CLI running as a pod in the cluster.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-local-volume.sh
    ```

    > It generates job manifest `local-volume-without-replica-fio.yaml` in `temp-local-fio/`

1. On a new terminal while the script is running check the state of the
   resources provisioned

    ```bash
    # Check that all the PVCs are provisioned
    $ kubectl get pvc

    # Use StorageOS CLI to verify where the volume is located
    $ kubectl -n kube-system exec cli -- storageos get volumes

    # Verify that the Pod is running in the same Node
    $ kubectl get pod -owide
    ```

1. Get the FIO results

    ```bash
    $ kubectl logs -f job.batch/local-volume-without-replica-fio
    ```

1. Cleanup FIO Job

    > Once the tests are finished, clean up using the following commands.

    ```bash
    $ kubectl delete -f ./tmp-local-fio/local-volume-without-replica-fio.yaml
    $ rm -rf ./tmp-local-fio
    ```

### Local Volume with a replica

The script `dbench-job-generator-local-volume-replica.sh` provisions a
StorageOS Volume with a replica
and a Pod on the same node and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance. It requires
the StorageOS CLI running as a pod in the cluster.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-local-volume-replica.sh
    ```

    > It generates job manifest `local-volume-with-replica-fio.yaml` in `temp-local-fio/`

1. On a new terminal while the script is running check the state of the
   resources provisioned

    ```bash
    # Check that all the PVCs are provisioned
    $ kubectl get pvc

    # Use StorageOS CLI to verify where the volume is located
    $ kubectl -n kube-system exec cli -- storageos get volumes

    # Verify that the Pod is running in the same Node
    $ kubectl get pod -owide
    ```

1. Get the FIO results

    ```bash
    $ kubectl logs -f job.batch/local-volume-with-replica-fio
    ```

1. Cleanup FIO Job

    > Once the tests are finished, clean up using the following commands.

    ```bash
    $ kubectl delete -f ./tmp-local-fio/local-volume-with-replica-fio.yaml
    $ rm -rf ./tmp-local-fio
    ```
