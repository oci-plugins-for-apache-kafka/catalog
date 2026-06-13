# Apache Kafka Connect File Plugin

This catalog entry builds OCI artifacts with the Apache Kafka Connect File plugin.

Upstream project: <https://github.com/apache/kafka>

Maven Central artifacts: <https://repo1.maven.org/maven2/org/apache/kafka/connect-file/>

## Images

| Version | Image |
|---|---|
| 4.3.0 | `ghcr.io/oci-plugins-for-apache-kafka/connect-file:4.3.0` |

## Connector Classes

```text
org.apache.kafka.connect.file.FileStreamSourceConnector
org.apache.kafka.connect.file.FileStreamSinkConnector
```

## Example Strimzi KafkaConnect Resource

```yaml
kind: KafkaConnect
metadata:
  name: my-connect
spec:
  template:
    pod:
      volumes:
        - name: connect-file
          image:
            reference: ghcr.io/oci-plugins-for-apache-kafka/connect-file:4.3.0
    connectContainer:
      volumeMounts:
        - name: connect-file
          mountPath: /opt/kafka/plugins/connect-file
```
