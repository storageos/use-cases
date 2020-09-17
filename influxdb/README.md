# InfluxDB on Kubernetes with StorageOS persistent Storage

This example shows an example of how to deploy InfluxDB on Kubernetes with
InfluxDB data being written to a StorageOS persistent volume. The files create a
stateful set that can be used *AFTER* a StorageOS cluster has been created. For
more information on how to install a StorageOS cluster please see
[the StorageOS documentation](https://docs.storageos.com/docs/introduction/quickstart).

## Deploy

In order to deploy InfluxDB you just need to clone this repository and use
kubectl to create the Kubernetes objects. 

```bash
$ git clone https://github.com/storageos/use-cases.git storageos-usecases
$ cd storageos-usecases
$ kubectl create -f ./influxdb
```

Once this is done you can check that an influxdb pod is running

```bash
$ kubectl get pods -w -l app=influx
   NAME        READY    STATUS    RESTARTS    AGE
   client      1/1      Running    0          1m
   influx-0     1/1      Running    0          1m
```

Connect to the InfluxDB client pod and connect to the InfluxDB server through the
service.

```bash
$ kubectl exec -it client -- influx -host influx-0.influx -username admin
Connected to http://influx-0.influx:8086 version 1.8.2
InfluxDB shell version: 1.8.2
> CREATE DATABASE weather;
> USE weather
Using database weather
> INSERT temperature,location=London value=26.4
> SHOW MEASUREMENTS
name: measurements
name
----
temperature
```

