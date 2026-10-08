source /opt/greengagedb/greengage7/greengage_path.sh
export COORDINATOR_DATA_DIRECTORY=/data1/coordinator/gpseg-1
export PGPORT=5432
export PGDATABASE=postgres

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PXF_HOME=/opt/greengagedb/pxf
export PXF_BASE=$HOME/pxf-base
export PATH=$PXF_HOME/bin:$JAVA_HOME/bin:$PATH
