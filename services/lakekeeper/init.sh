#!/bin/sh
# Prepares the Lakekeeper REST catalog for the demo cluster:
# creates the S3 bucket, bootstraps Lakekeeper, and creates the warehouse.
# The script is idempotent: steps that are already done are skipped.
set -eu

CATALOG=http://iceberg-rest:8181
PROJECT_ID=00000000-0000-0000-0000-000000000000

mc alias set s3 http://minio:9000 minioadmin minioadmin >/dev/null
mc mb --ignore-existing s3/warehouse

case "$(curl -sf "$CATALOG/management/v1/info")" in
*'"bootstrapped":true'*)
    echo "Lakekeeper is already bootstrapped"
    ;;
*)
    curl -sS --fail-with-body -X POST "$CATALOG/management/v1/bootstrap" \
        -H 'Content-Type: application/json' \
        --data '{"accept-terms-of-use": true}'
    echo "Lakekeeper is bootstrapped"
    ;;
esac

case "$(curl -sf "$CATALOG/management/v1/warehouse?project-id=$PROJECT_ID")" in
*'"name":"demo"'*)
    echo "Warehouse demo already exists"
    ;;
*)
    curl -sS --fail-with-body -X POST "$CATALOG/management/v1/warehouse" \
        -H 'Content-Type: application/json' \
        --data @/init/warehouse.json
    echo
    echo "Warehouse demo is created"
    ;;
esac
