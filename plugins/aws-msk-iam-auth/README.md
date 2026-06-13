# Amazon MSK Library for AWS Identity and Access Management

This catalog entry builds OCI artifacts with the Amazon MSK Library for AWS Identity and Access Management.

Upstream project: <https://github.com/aws/aws-msk-iam-auth>

## Images

| Version | Image |
|---|---|
| 2.3.7 | `ghcr.io/oci-plugins-for-apache-kafka/aws-msk-iam-auth:2.3.7` |

## Example Strimzi `KafkaConnect` Resource

```yaml
kind: KafkaConnect
metadata:
  name: my-connect
spec:
  authentication:
    type: custom
    sasl: true
    config:
      sasl.mechanism: AWS_MSK_IAM
      sasl.jaas.config: software.amazon.msk.auth.iam.IAMLoginModule required;
      sasl.client.callback.handler.class: software.amazon.msk.auth.iam.IAMClientCallbackHandler
  template:
    pod:
      volumes:
        - name: aws-msk-iam-auth
          image:
            reference: ghcr.io/oci-plugins-for-apache-kafka/aws-msk-iam-auth:2.3.7
    connectContainer:
      volumeMounts:
        - name: aws-msk-iam-auth
          mountPath: /mnt/aws-msk-iam-auth
      env:
        - name: CLASSPATH
          value: "/mnt/aws-msk-iam-auth/*"
```
