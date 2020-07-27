# Synthetic Benchmarks

## DBench FIO Tests

### Remote Volume with no replicas

The script `dbench-job-generator-remote-volume.sh` provisions a StorageOS Volume
and a Pod on diffrent nodes and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance.
1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-remote-volume.sh
    ```

    > It generates job manifest `remote-volume-without-replica-fio.yaml` in `$TMPDIR`.

1. On a new terminal while the script is running check the state of the
   resources provisioned

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
    $ kubectl logs -f job.batch/remote-volume-without-replica-fio
    ```

1. Cleanup FIO Job

    > Once the tests are finished, clean up using the following commands.

    ```bash
    $ kubectl delete -f ./tmp-remote-fio/remote-volume-without-replica-fio.yaml
    $ rm -rf ./tmp-remote-fio
    $ rm -rf ./tmp-fio-logs
    ```

### Remote Volume with a replica

The script `dbench-job-generator-remote-volume-replica.sh` provisions a
StorageOS Volume with a replica
and a Pod on the same node and then will execute a series of FIOs (15s per FIO
test) on the provisioned volume to measure StorageOS performance.

1. Generate the FIO job

    ```bash
    $ ./dbench-job-generator-remote-volume-replica.sh
    ```

    > It generates job manifest `remote-volume-with-replica-fio.yaml` in `$TMPDIR`.

1. On a new terminal while the script is running check the state of the
   resources provisioned

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
    $ kubectl logs -f job.batch/remote-volume-with-replica-fio
    ```
