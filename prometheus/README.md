# Setting up Prometheus to Monitor StorageOS

CoreOS have created a Kubernetes Operator for installing Prometheus. The
operator uses ServiceMonitor custom resources (CRs) to scrape IP addresses
defined in Kubernetes Endpoints. This article is intended to provide a quick
guide to monitoring the StorageOS metrics endpoint and can be used with our
example [Grafana dashboard](https://grafana.com/dashboards/10093).

> N.B The standard installation does not use persistent volumes for the
> Prometheus pod. If you wish to add persistent storage for the pod please
> uncomment the lines in ./manifests/010-prometheus-cr.yaml. If you also wish
> to add persistence Grafana then use `helm install stable/grafana -f
> grafana-helm-values`, or if using the yaml manifests create the
> grafana-pvc.yaml.example file and edit the grafana-deployment.yaml to use the
> PersistentVolumeClaim rather than an emptyDir.

## Scripted Installation

For convenience a scripted installation of Prometheus, monitoring StorageOS,
using the Prometheus Operator has been created. If you are comfortable running
the scripted installation simply run the install-prometheus.sh script. 

```bash
./install-prometheus.sh
```

If you wish to install Grafana using helm or manually using the yaml manifests
please see Install Grafana

```bash
./install-grafana.sh
```


## Install Prometheus and the Prometheus Operator

This is the Prometheus use case for StorageOS. Following are the steps
for creating a Prometheus instance and using StorageOS to handle its
persistent storage. For more information check our Prometheus use case
[documentation](https://docs.storageos.com/docs/usecases/prometheus)

1. Create the Prometheus objects.

   ```bash
   $ ./install-prometheus.sh
   ```

1. Confirm Prometheus is up and running.

   ```bash
   $ kubectl get pods -w -l app=prometheus
   NAME                                READY   STATUS              RESTARTS   AGE
   prometheus-prometheus-storageos-0   3/3     READY               0          1m
   ```

1. You can see the created PVC using.
    ```bash
    $ kubectl get pvc
    NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS           AGE
    data-prometheus-prometheus-storageos-0   Bound    pvc-b6c17c0a-e76b-4a0b-8fc6-46c0e1629210   1Gi        RWO            storageos-replicated   65m
    ```

1. In the Prometheus deployment script, a service monitors is also created. 
The new Prometheus instance will use the storageos-etcd service monitor to 
start scraping metrics from the storageos-etcd pods. (Assuming the storageos 
cluster was setup using ETCD as pods) For more information about service 
monitors, have a look at the upstream [documentation](https://coreos.com/operators/prometheus/docs/latest/user-guides/getting-started.html).
   ```bash
    $ kubectl get servicemonitor                       
    NAME             AGE
    storageos-etcd   5d1h
    ```

1. Port forward in the prometheus pod to access the prom webapp.
   ```bash
   $ kubectl port-forward prometheus-prometheus-storageos-0 9090
   ```
   Then go on a web browser and type the url `localhost:9090` to access the 
   prometheus webapp. Confirm that prometheus is up and running there.

## Install Grafana

Grafana is a popular solution for visualising metrics. At the time of writing
(30/04/2019) there is no Grafana operator so instead a helm installation is
used. If a helm installation will not work then the helm generated manifests
can be used.

1. Install Grafana - Either helm can be used or the yaml manifests in
   ./manifests/grafana/
   ```bash
   helm install stable/grafana
   ```
   ```bash
   kubectl create -f ./manifests/grafana/
   ```
1. Grafana can query the Prometheus pod for metrics, through a Service. The
   Prometheus operator automatically creates a service in any namespace that a
   Prometheus resource is created in. Setup a Grafana data source that points at
   the Prometheus service that was created. The URL to use will depend on the
   namespace that Grafana is installed into.

   If the Grafana pod runs in the same namespace as the
   Prometheus pod then the URL is: `http://prometheus-operated:9090` otherwise it's
   `http://prometheus-operated.$NAMESPACE.svc:9090`

   When creating the data source make sure to set the scrape interval.

1. Once the Prometheus data source has been created have a look at the [example
   StorageOS dashboard](https://grafana.com/dashboards/10093) for ideas about
   how to monitor your cluster. You may also be interested in our etcd
   monitoring dashboards ([etcd running as
   pods](https://grafana.com/dashboards/10323), [etcd running as an external
   service](https://grafana.com/dashboards/10322))
