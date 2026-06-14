# Debezium Connectors

This catalog entry builds OCI artifacts with Debezium Kafka Connect connector plugin packages.

Upstream project: <https://github.com/debezium/debezium>

Maven Central artifacts: <https://repo1.maven.org/maven2/io/debezium/>

## Version

The catalog currently includes Debezium `3.5.2.Final`, the latest stable `Final` release published in Maven Central metadata when this entry was added.

## Images

Each Debezium connector plugin package is published as a separate image tag:

```text
ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-<connector-id>
```

Examples:

```text
ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-postgres
ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-mysql
ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-jdbc
```

The connector id is the Maven artifact name without the `debezium-connector-` prefix.

## Example Strimzi KafkaConnect Resource

```yaml
kind: KafkaConnect
metadata:
  name: my-connect
spec:
  template:
    pod:
      volumes:
        - name: debezium-postgres
          image:
            reference: ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-postgres
    connectContainer:
      volumeMounts:
        - name: debezium-postgres
          mountPath: /opt/kafka/plugins/debezium-postgres
```
