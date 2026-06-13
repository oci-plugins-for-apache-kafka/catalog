# Aiven Tiered Storage Plugins for Apache Kafka

This catalog entry builds OCI artifacts with the Aiven tiered storage plugins for Apache Kafka.

Upstream project: <https://github.com/Aiven-Open/tiered-storage-for-apache-kafka>

## Images

| Plugin | Image |
|---|---|
| Filesystem | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-filesystem` |
| Amazon S3 | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-s3` |
| Google Cloud Storage | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-gcs` |
| Azure Blob Storage | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-azure` |

## Example Strimzi Kafka Resource

```yaml
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    template:
      pod:
        volumes:
          - name: aiven-tiered-storage
            image:
              reference: ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-filesystem
      kafkaContainer:
        volumeMounts:
          - name: aiven-tiered-storage
            mountPath: /mnt/aiven-tiered-storage
        env:
          - name: CLASSPATH
            value: "/mnt/aiven-tiered-storage/*"
```
