# Greengage DB demo cluster

This demo cluster serves as a Greengage DB sandbox environment.
The cluster image is based on Ubuntu 22.04.
Greengage DB, PXF, and `gpbackup` are installed from the official Greengage DB APT repository:

- Greengage DB is installed to _/opt/greengagedb/greengage7_ as described in [Install Greengage DB from a package](https://greengagedb.org/en/docs-gg/current/install_from_package.html).
- PXF is installed to _/opt/greengagedb/pxf_ as described in [Install PXF from a package](https://greengagedb.org/en/docs-pxf/current/install_from_package.html).
  JDK 17 required by PXF is installed from the Ubuntu repository.
- The `gpbackup` and `gprestore` utilities are installed to _/opt/greengagedb/gpbackup_ and linked to the Greengage DB _bin_ directory.

Environment variables for Greengage DB and PXF are set in [configs/.bashrc](configs/.bashrc), which is mounted to the `gpadmin` home directory on all cluster hosts.

The [examples](examples) directory is mounted to the containers to share files with them, for example, scripts and data files used in documentation examples.
To use another directory, for example, the _examples_ directory of the Greengage DB documentation repository, set its path in the `EXAMPLES_DIR` environment variable or in the _.env_ file:

```shell
$ echo "EXAMPLES_DIR=/path/to/examples" > .env
```

## Start containers

1. Go to the repository directory:
   ```shell
   $ cd greengagedb_demo_cluster
   ```
2. (Optional) To reinitialize the cluster, remove its containers and volumes:
   ```shell
   $ docker compose down -v --remove-orphans
   ```
3. Build images and start cluster instances:
   ```shell
   $ docker compose build
   $ docker compose up
   ```
   To run auxiliary services, see the section below before running `docker compose up`.

## (Optional) Run auxiliary services

### Overview

You can start a cluster together with auxiliary services to replicate documentation examples that work with external data or connect to the cluster from a client host.
Service definitions are stored in the _services_ directory.
To run a service, provide its `yaml` definition and the definitions of the services it requires using the `-f` parameter.
To stop a cluster with auxiliary services, pass the same `-f` parameters to `docker compose down`.
Running the cluster together with all auxiliary services requires about 6 GB of memory available to Docker, so start only the services required for your scenario.

To move a file between containers, for example, from `cdw` to `namenode`, copy it through the host machine:

```shell
$ docker cp cdw:/tmp/<file> .
$ docker cp <file> namenode:/tmp/
```

### Services

| Service | Definition | Requires | Description |
|---|---|---|---|
| PostgreSQL | _postgres/postgres.compose.yaml_ | - | PostgreSQL server |
| psql client | _psql-client/psql-client.compose.yaml_ | - | Client host with `psql` |
| S3 | _s3/s3.compose.yaml_ | - | S3-compatible object storage ([Silo](https://silo.pigsty.io), a fork of MinIO) |
| HDFS | _hdfs/hdfs.compose.yaml_ | - | Single-node HDFS cluster |
| Lakekeeper | _lakekeeper/lakekeeper.compose.yaml_ | S3 | Iceberg REST catalog ([Lakekeeper](https://docs.lakekeeper.io)) |
| Hive Metastore | _hive-metastore/hive-metastore.compose.yaml_ | HDFS | Hive Metastore ([Apache Hive](https://hive.apache.org)) |
| Trino | _trino/trino.compose.yaml_ | Lakekeeper or Hive Metastore | SQL engine for Iceberg tables ([Trino](https://trino.io)) |

### Scenarios

To access external data using PXF, copy the PXF server configurations as described in [(Optional) Start PXF](#optional-start-pxf).

#### External PostgreSQL database

Run a cluster together with the PostgreSQL server:

```shell
$ docker compose -f compose.yaml \
    -f services/postgres/postgres.compose.yaml \
    up
```

The server is available at `postgres:5432` from the cluster hosts and at `localhost:5555` from the host machine.
Connect as the `postgres` user without a password; the default database is `default`.

#### Client host

Run a cluster together with the client host, which is used to connect to the cluster as `alice`:

```shell
$ docker compose -f compose.yaml \
    -f services/psql-client/psql-client.compose.yaml \
    up
```

To connect to the client host, run:

```shell
$ docker exec -it psql-client bash
```

#### Files in S3

Run a cluster together with the S3 storage:

```shell
$ docker compose -f compose.yaml \
    -f services/s3/s3.compose.yaml \
    up
```

- The S3 API is available at `http://minio:9000` from the cluster hosts.
- The web console is available at http://localhost:9001.
- The access key and the secret key are `minioadmin`.
- The `s3` PXF server provides access to the files.

To create a bucket and upload a file from the _examples_ directory to it, use the `mc` client in the `minio` container:

1. Connect to the container:
   ```shell
   $ docker exec -it minio bash
   ```
2. Create a bucket:
   ```shell
   $ mc mb local/<bucket>
   ```
3. Upload a file:
   ```shell
   $ mc cp /examples/<example_dir>/<file> local/<bucket>/
   ```

#### Files in HDFS

Run a cluster together with HDFS:

```shell
$ docker compose -f compose.yaml \
    -f services/hdfs/hdfs.compose.yaml \
    up
```

- HDFS is available at `hdfs://namenode:8020` from the cluster hosts.
- The NameNode web UI is available at http://localhost:9870.
- The `hadoop` PXF server provides access to the files.

To upload a file from the _examples_ directory to HDFS, use the `hdfs` client in the `namenode` container:

1. Connect to the container:
   ```shell
   $ docker exec -it namenode bash
   ```
2. Create a directory:
   ```shell
   $ hdfs dfs -mkdir -p <hdfs_dir>
   ```
3. Upload a file:
   ```shell
   $ hdfs dfs -put /examples/<example_dir>/<file> <hdfs_dir>/
   ```

#### Iceberg tables in S3 with a REST catalog

Run a cluster together with the S3 storage, Lakekeeper, and Trino:

```shell
$ docker compose -f compose.yaml \
    -f services/s3/s3.compose.yaml \
    -f services/lakekeeper/lakekeeper.compose.yaml \
    -f services/trino/trino.compose.yaml \
    up
```

- The catalog is available at `http://iceberg-rest:8181/catalog` from the cluster hosts.
- The catalog has the `demo` warehouse, which stores data in the S3 storage.
- The Lakekeeper web UI is available at http://localhost:8181/ui.
- The `iceberg` PXF server provides access to the tables.
  When you create a foreign server or a user mapping for the catalog, specify `http://iceberg-rest:8181/catalog` as the catalog URI and `minioadmin` as the S3 access key and secret key.

To create and query the tables, connect to Trino using the `iceberg_rest` catalog:

```shell
$ docker exec -it trino trino --catalog iceberg_rest
```

#### Iceberg tables in HDFS with a Hive Metastore catalog

Run a cluster together with HDFS, Hive Metastore, and Trino:

```shell
$ docker compose -f compose.yaml \
    -f services/hdfs/hdfs.compose.yaml \
    -f services/hive-metastore/hive-metastore.compose.yaml \
    -f services/trino/trino.compose.yaml \
    up
```

- The metastore is available at `thrift://hive-metastore:9083` from the cluster hosts.
- The metastore stores table data in HDFS, in the _/user/hive/warehouse_ directory.
- The `iceberg_hive` PXF server provides access to the tables.

To create and query the tables, connect to Trino using the `iceberg_hive` catalog:

```shell
$ docker exec -it trino trino --catalog iceberg_hive
```

## Initialize a cluster

1. Connect to the coordinator host:
   ```shell
   $ docker exec -it cdw bash
   $ su - gpadmin
   $ source .bashrc
   ```
2. Initialize a cluster:
   - Create the data storage areas:
     ```shell
     $ sudo mkdir -p /data1/coordinator
     $ sudo chown gpadmin:gpadmin /data1/coordinator
     $ gpssh -h scdw -e 'sudo -n mkdir -p /data1/coordinator'
     $ gpssh -h scdw -e 'sudo chown gpadmin:gpadmin /data1/coordinator'
     $ gpssh -f hostfile_segment_hosts -e 'sudo mkdir -p /data1/primary'
     $ gpssh -f hostfile_segment_hosts -e 'sudo mkdir -p /data1/mirror'
     $ gpssh -f hostfile_segment_hosts -e 'sudo chown -R gpadmin /data1/*'
     ```
   - Initialize Greengage DB:
     ```shell
     $ gpinitsystem -c init_config \
         -h hostfile_segment_hosts \
         -s scdw \
         -n en_US.UTF-8
     ```
3. Edit _pg_hba.conf_ to allow local connections for all users and remote connections for `gpadmin` and `alice`:
   ```shell
   $ cat >> "$COORDINATOR_DATA_DIRECTORY/pg_hba.conf" <<EOF
   local   all    all      trust
   host    all    gpadmin  0.0.0.0/0  trust
   host    all    alice    192.168.10.55/32  trust
   EOF
   ```
4. Apply the new configuration:
   ```shell
   $ gpstop -u
   ```
5. Check that all cluster instances are up:
   ```shell
   $ psql -c 'SELECT content, role, hostname, status FROM gp_segment_configuration;'
   ```

## (Optional) Start PXF

PXF is required only for examples that work with external data, such as the S3, HDFS, Iceberg, or JDBC examples.
PXF is not active after installation.
Before using the framework, you must explicitly initialize and start the PXF service.
The `PXF_HOME`, `PXF_BASE`, and `JAVA_HOME` environment variables are already set on all hosts, so you do not need to edit _$PXF_BASE/conf/pxf-env.sh_.
Run the following commands on the coordinator host as `gpadmin`:

1. Prepare a new base directory specified by the `PXF_BASE` environment variable (_/home/gpadmin/pxf-base_):
   ```shell
   $ pxf cluster prepare
   ```
2. (Optional) If you run auxiliary services, copy the PXF server configurations for them (`s3`, `hadoop`, `iceberg`, and `iceberg_hive`) from [configs/pxf/servers](configs/pxf/servers):
   ```shell
   $ cp -r ~/pxf-servers/* $PXF_BASE/servers/
   ```
3. Synchronize the server configuration to the Greengage DB cluster hosts:
   ```shell
   $ pxf cluster sync
   ```
4. Start the PXF service on all Greengage DB cluster hosts:
   ```shell
   $ pxf cluster start
   ```
5. (Optional) Check the PXF status:
   ```shell
   $ pxf cluster status
   ```

To use PXF in a database, register the PXF extensions in it.
The `pxf` extension is required for external tables, and the `pxf_fdw` extension is required for foreign tables.
To work with both table types, register both extensions:

```sql
CREATE EXTENSION pxf;
CREATE EXTENSION pxf_fdw;
```

Each time you add or change server configurations in _$PXF_BASE/servers_, synchronize them to the cluster hosts by using `pxf cluster sync`.

## Stop a cluster

1. (Optional) If PXF is running, stop the PXF service on all cluster hosts:
   ```shell
   $ pxf cluster stop
   ```
2. Stop the cluster:
   ```shell
   $ gpstop -a
   ```
3. Stop containers:
   ```shell
   $ docker compose down
   ```
   If you started auxiliary services, pass the same `-f` parameters, or add the `--remove-orphans` option to remove the containers of all services not defined in _compose.yaml_.

## Start an existing cluster

Cluster data is stored in the `greengage7_*` volumes and persists after the containers are stopped.
To start a previously initialized cluster:

1. Start containers:
   ```shell
   $ docker compose up
   ```
   If you use auxiliary services, pass the same `-f` parameters as when you started them for the first time.
2. Connect to the coordinator host:
   ```shell
   $ docker exec -it cdw bash
   $ su - gpadmin
   $ source .bashrc
   ```
3. Start the cluster:
   ```shell
   $ gpstart -a
   ```
4. (Optional) If PXF was started before, start the PXF service on all cluster hosts:
   ```shell
   $ pxf cluster start
   ```
