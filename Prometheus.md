# Prometheus, Loki and Grafana

## Prometheus

## what is prometheus?
- Monitoring tool for dynamic cloud environment(like containers). It only does metric.
- constant Monitoring

## Architecture:
![Diagram for prometheus architecture ](https://prometheus.io/assets/architecture.png)


There are 3 main components in a prometheus application.
- Storage - Time series database
- Data retrival worker, pulls data from applications and services
- HTTP server - exposes API using PromQL



It uses pull mechanism to pull metics from system, it also uses diffrent exporters for the same.
Prometheus uses "exporter" to fetch data on host machine and expose it so server can pull it, there are many exports for diffrent services.

Push mechanism:There is also push mechanism available for short term runnuing services.


## Storage - Time series database


Earlier prometheus used LevelDB to store all the metric data. 

Each series comtain multiple samples, each file in a period of time stores all of its samples in sequential order.We batch up 1KiB chunks of samples for a series in memory and append those chunks to the individual files.

### Problem

By its architecture the V2 storage slowly builds up chunks of sample data, which causes the memory consumption to ramp up over time. As chunks get completed, they are written to disk and can be evicted from memory. Eventually, Prometheus’s memory usage reaches a steady state. That is until the monitored environment changes — series churn increases the usage of memory, CPU, and disk IO every time we scale an application or do a rolling update.

Churn happnes when application is updated and all the erlier series becomes obsolete and new data in new series start to roll in.

![series](https://raw.githubusercontent.com/neeraj9194/observation-config/master/img/series.png)

### New TSDB

Now the data is stored in blocks, every block of data is immutable. Each block acts as a fully independent database containing all time series data for its time window.  


![chunks](https://raw.githubusercontent.com/neeraj9194/observation-config/master/img/chunk.png)






