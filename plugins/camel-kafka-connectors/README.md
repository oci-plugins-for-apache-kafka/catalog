# Apache Camel Kafka Connect Connectors

This catalog entry builds OCI artifacts with Apache Camel Kafka Connect connector packages.

Upstream project: <https://github.com/apache/camel-kafka-connector>

Maven Central artifacts: <https://repo1.maven.org/maven2/org/apache/camel/kafkaconnector/>

## Version

The catalog currently includes Apache Camel Kafka Connector `4.18.0`, the latest stable release published in Maven Central metadata when this entry was added.

## Images

Each Camel connector package is published as a separate image tag:

```text
ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-<connector-id>
```

Examples:

```text
ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-file
ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-s3-sink
ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-http-sink
```

The connector id is the Maven artifact name without the `camel-` prefix and `-kafka-connector` suffix.

## Example Strimzi `KafkaConnect` Resource

```yaml
kind: KafkaConnect
metadata:
  name: my-connect
spec:
  template:
    pod:
      volumes:
        - name: camel-file
          image:
            reference: ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-file
    connectContainer:
      volumeMounts:
        - name: camel-file
          mountPath: /opt/kafka/plugins/camel-file
```
