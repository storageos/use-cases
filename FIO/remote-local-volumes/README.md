# Create jobs

## StorageOS FIO tests

The volumes in this tests will be created without node selectors or hints,
therefore some volumes may be local to the FIO Pod and some remote. To test
using local volumes, look at the suggested tests in `../local-volumes/`.

### Tests suggested

> If you want to generate your tests, skip to the section "Generate tests".

> You can tweak the FIO profiles in `./profiles/` to fulfill your needs.

1. Upload FIO profiles as ConfigMaps

```bash
~$ ./upload-fio-profiles.sh
```

The uploader creates a ConfigMap with all the FIO config files that will be
injected into the Job.

2. Run the tests

```bash
~$ kubectl create -f ./jobs/$JOB.yaml

```

3. Check the provisioning

```bash
~$ # Check that all the PVCs are provisioned 
~$ kubectl get pvc

# Use StorageOS CLI to verify where the volumes are collocated

# As a binary
~$ storageos get volumes 

# As a container
~$ kubectl -n storageos exec cli -- storageos get volumes


# Verify that the Pod is running
~$ kubectl get pod -owide
```

4. Get the FIO results

```bash
~$ kubectl logs $POD
```

## Generate tests

Initial test specs are already defined in the jobs and profiles directories.
However, those are supplied as examples. If you wish to test other setups, you
can generate the tests with the Job Generator.

### 4, 8, 16 and 32 volumes


The script `job-generator-per-volumecount.sh` takes by parameter the number of
concurrent volumes to be used in the test.

```bash
~$ ./job-generator-per-volumecount.sh 4
~$ ./job-generator-per-volumecount.sh 8
~$ ./job-generator-per-volumecount.sh 16
~$ ./job-generator-per-volumecount.sh 32
```

The Job Generator creates a Job in `./jobs/` for each execution and its
according FIO profile file `./profiles/`. You can change the size of the
volumes by editing the ./jobs file.

You can edit the FIO profile to supply your own FIO parameters and upload
the ConfigMap again by executing `./upload-fio-profiles.sh`.

## DBench FIO Tests

### Remote Volume with no replicas

The script `dbench-job-generator-remote-volume.sh` provisions a StorageOS Volume
and a Pod on diffrent nodes and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance. It requires
the StorageOS CLI running as a pod in the cluster.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-remote-volume.sh
    ```

    > It generates a Job in `temp-remote-fio/`

1. Run the FIO tests

    ```bash
    $ kubectl create -f ./tmp-remote-fio/dbench.yaml
    ```

1. Check resources were provisioned

    ```bash
    # Check that all the PVCs are provisioned
    $ kubectl get pvc

    # Use StorageOS CLI to verify where the volume is located
    $ kubectl -n kube-system exec cli -- storageos get volumes

    # Verify that the Pod is running on a different Node
    $ kubectl get pod -owide
    ```

1. Get the FIO results

    ```bash
    $ kubectl logs -f job.batch/tmp-remote-fio
    ```

1. Cleanup FIO Job

    > Once the tests are finished, clean up using the following commands.

    ```bash
    $ kubectl delete -f ./tmp-remote-fio/dbench.yaml
    $ rm -rf ./tmp-remote-fio
    ```

### Remote Volume with a replica

The script `dbench-job-generator-remote-volume-replica.sh` provisions a
StorageOS Volume with a replica
and a Pod on the same node and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance. It requires
the StorageOS CLI running as a pod in the cluster.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-remote-volume-replica.sh
    ```

    > It generates a Job in `temp-remote-fio/`

1. Run the FIO tests

    ```bash
    $ kubectl create -f ./tmp-remote-fio/dbench.yaml
    ```

1. Check resources were provisioned

    ```bash
    # Check that all the PVCs are provisioned
    $ kubectl get pvc

    # Use StorageOS CLI to verify where the volume is located
    $ kubectl -n kube-system exec cli -- storageos get volumes

    # Verify that the Pod is running a different Node
    $ kubectl get pod -owide
    ```

1. Get the FIO results

    ```bash
    $ kubectl logs -f job.batch/remote-volume-fio
    ```

1. Cleanup FIO Job

    > Once the tests are finished, clean up using the following commands.

    ```bash
    $ kubectl delete -f ./tmp-remote-fio/dbench.yaml
    $ rm -rf ./tmp-remote-fio
    ```
