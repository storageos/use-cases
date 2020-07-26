# Synthetic Benchmarks

## DBench FIO Tests

### Local Volume with no replicas

The script `dbench-job-generator-local-volume.sh` provisions a StorageOS Volume
and a Pod on the same node and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-local-volume.sh
    ```

    > It generates job manifest `local-volume-without-replica-fio.yaml` in `$TMPDIR`.

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
test) on the provisioned volume to measure StorageOS performance.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-local-volume-replica.sh
    ```

    > It generates job manifest `local-volume-with-replica-fio.yaml` in `$TMPDIR`.

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
