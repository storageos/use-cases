# InfluxDB on Kubernetes with StorageOS persistent Storage

This is an example of how to deploy InfluxDB on Kubernetes, writing
InfluxDB data to a StorageOS persistent volume. The files create a
StatefulSet that can be used *AFTER* a StorageOS cluster has been created. For
more information on how to install a StorageOS cluster please see
[the StorageOS documentation](https://docs.storageos.com/docs/introduction/quickstart).

## Deploy

To deploy InfluxDB, clone this repository and use
kubectl to create the Kubernetes objects. 

```bash
$ git clone https://github.com/storageos/use-cases.git storageos-usecases
$ cd storageos-usecases
$ kubectl create -f ./influxdb
```

Once this is done you can check that an InfluxDB pod is running.

```bash
$ kubectl get pods
   NAME        READY    STATUS    RESTARTS    AGE
   client      1/1      Running    0          1m
   influxdb-0     1/1      Running    0          1m
```

Connect to the InfluxDB client pod and connect to the InfluxDB server through the
service.

```bash
$ kubectl exec -it influxdb-client -- bash
root@influxdb-client:/# influx -host influxdb-0.influxdb
Connected to http://influxdb-0.influxdb:8086 version 1.8.2
InfluxDB shell version: 1.8.2
> auth
username: admin
password: 
> show databases
name: databases
name
----
_internal
> CREATE DATABASE weather;
> USE weather
Using database weather
> INSERT temperature,location=London value=26.4
> INSERT temperature,location=London value=24.9
> INSERT temperature,location=London value=22.2
> INSERT temperature,location=London value=14.7
> INSERT temperature,location=London value=19.5
> INSERT temperature,location=Paris value=27.1
> INSERT temperature,location=Paris value=27.5
> INSERT temperature,location=Paris value=21.3
> INSERT temperature,location=Paris value=26.7
> INSERT temperature,location=Paris value=30.0
> SELECT MEAN(*) FROM "temperature" GROUP BY "location"
name: temperature
tags: location=London
time mean_value

0    25.65

name: temperature
tags: location=Paris
time mean_value

0    26.90
```

