# Echo Sink Plugin

This catalog entry builds OCI artifacts with the Echo Sink plugin.

Upstream project: <https://github.com/scholzj/echo-sink>

## Images

| Version | Image |
|---|---|
| 1.6.0 | `ghcr.io/oci-plugins-for-apache-kafka/echo-sink:1.6.0` |

## Connector Classes

```text
cz.scholz.kafka.connect.echosink.EchoSinkConnector
```

## Example Strimzi `KafkaConnect` Resource

```yaml
kind: KafkaConnect
metadata:
  name: my-connect
spec:
  template:
    pod:
      volumes:
        - name: echo-sink
          image:
            reference: ghcr.io/oci-plugins-for-apache-kafka/echo-sink-1.6.0
    connectContainer:
      volumeMounts:
        - name: echo-sink
          mountPath: /opt/kafka/plugins/echo-sink
```

## Configuration options

| Option                    | Description                                                                                                                                                                                                                                                                                                                    | Default |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `level`                   | Defines the log level on which the received messages will be logged.                                                                                                                                                                                                                                                           | `INFO`  |
| `fail.task.after.records` | The tasks created by this connector will fail after receiving the specified number of records with an error. This is useful to test things such as status updated at task failures or automatic task restarts. If set to `0` or not set at all, this feature will be disabled and the connector will never fail intentionally. | `0`     |
| `fail.connector.startup`  | The connector will fail at startup. When set to true, the connector instance will never get running.                                                                                                                                                                                                                           | `false` |