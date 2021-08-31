# Loki

Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus. It is designed to be very cost effective and easy to operate. It does not index the contents of the logs, but rather a set of labels for each log stream.


Promtail： Log collector. You can collect logs from log files , And push the collected data to Loki In the middle .
Loki： Aggregate and store log data , It can be used as Grafana Data source , by Grafana Provide visual data .
Grafana： from Loki Get log information from , Make a visual presentation .



## Architecture

![Diagram shows the key components of the loki ](https://grafana.com/docs/loki/latest/architecture/loki_architecture_components.svg)


## Distributor

- The distributor service is responsible for handling incoming streams by clients. 
-  Once the distributor receives a set of streams, each stream is validated for correctness and to ensure that it is within the configured tenant (or global) limits. 
- Valid chunks are then split into batches and sent to multiple ingesters in parallel.


## Ingester

Ingester service is responsible for writing log data to long-term storage backends. You can configure storage in storage_config.

Loki needs to store two different types of data: chunks and indexes. The index stores each stream’s label set and links them to the individual chunks.

Below is the config to store chuncks in AWS S3.

```
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: aws
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  aws:
    # The period behind the domain forces the S3 library to use it as a host name, not as an AWS region.
    s3: s3://access_key:secret_access_key@region/bucket_name
    s3forcepathstyle: true
  boltdb_shipper:
    active_index_directory: /tmp/loki/boltdb-shipper-active
    cache_location: /tmp/loki/boltdb-shipper-cache
    cache_ttl: 24h         # Can be increased for faster performance over longer query periods, uses more disk space
    shared_store: s3
```

### BoltDB Shipper (Single Store Loki)

Other than native cloud storage options loki also provides its own storage mechnaism to store chunks. 
BoltDB Shipper lets you run Loki without any dependency on NoSQL stores for storing index. 

- It stores the index in BoltDB files instead and keeps shipping those files to a shared object store(S3 etc.).

Config for bolt-DB

```
schema_config:
  configs:
    - from: 2018-04-15
      store: boltdb-shipper
      object_store: gcs
      schema: v11
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  gcs:
    bucket_name: GCS_BUCKET_NAME

  boltdb_shipper:
    active_index_directory: /loki/index
    shared_store: gcs
    cache_location: /loki/boltdb-cache
```


## Compactor

The Compactor can deduplicate index entries. It can also apply granular retention in newer version of loki.

> Currently the compactor retention works only if the index period is 24h. Use table manager otherwise.

Steps performed by compactor,

- Compact the table into a single index file.
- Traverse the entire index. Use the tenant configuration to identify and mark chunks that need to be removed.
- Remove marked chunks from the index and save their reference in a file on disk.
- Upload the new modified index files.


Common setting for enabling compactor, if enabled for retention the Table Manager is unnecessary.

```
compactor:
  working_directory: /tmp/loki/boltdb-shipper-compactor
  shared_store: s3
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150   # maximum quantity of goroutine workers instantiated to delete chunks.
```

Configure compactor retention period,

```
limits_config:
  # Global retention period
  retention_period: 744h
  
  # Retention based on chunks matching selector
  retention_stream:
  - selector: '{namespace="dev"}'
    priority: 1
    period: 24h
```

Here the logs will be retained for 744h and then will be marked for deletion. Logs will then be deleted after 2hr delay as mentioned in config `retention_delete_delay`.


Retention period can also be set per tenant basis, if we enable multitenant acrhitecture in loki we can configure thet using `per_tenant_override_config: /etc/overrides.yaml` config.


## Pipeline

Parsing stages parse the current log line and extract data out of it. The extracted data is then available for use by other stages.
- Transform stages transform extracted data from previous stages.
- Action stages take extracted data from previous stages and do something with them. Actions can:
    - Add or modify existing labels to the log line
    - Change the timestamp of the log line
    - Change the content of the log line
    - Create a metric based on the extracted data
- Filtering stages optionally apply a subset of stages or drop entries based on some condition.


Pipelines will start with a parsing stage (such as a regex or json stage) to extract data from the log line. Then, a series of action stages will be present to do something with that extracted data. The most common action stage will be a labels stage to turn extracted data into a label.


To delete a log line you can use pipelines

```
  pipeline_stages:
  - match:
      selector: '{job="django-debug"}'
      stages:
      - drop:
          expression: ".*site-packages*"
```

This will delete log line containing "site-packages".


You can also add a tenant ID in promtail which is used for multitenant architecture in Loki.

```
pipeline_stages:
  - json:
      expressions:
        app:
        message:
  - labels:
      app:
  - match:
      selector: '{app="api"}'
      stages:
        - tenant:
            value: "team-api"
  - output:
      source: message
```



## FAQs


**Q:** Can I configure to send only few type of logs to S3 and rest others only from local system.

**A:** No, but what you can do is setup a multi-tenant/or multi instance loki so you have different config for each one.

##

**Q:** Using same S3 bucket for multiple Loki installations but different sub-paths?

**A:** It is accomplished by multitenancy in Loki which can be enabled by setting a X-Scope-OrgID header that way the data will be separate.

##
