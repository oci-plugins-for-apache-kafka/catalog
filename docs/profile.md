# OCI Plugins for Apache Kafka

This organization contains OCI artifacts with Apache Kafka plugins.
The artifacts can be mounted into Kubernetes workloads as image volumes, avoiding custom container images for common plugin use cases.

This organization is not part of the Apache Kafka project.

## Currently Supported Plugins

| Plugin | Images | Upstream |
|---|---|---|
| [Aiven Tiered Storage plugins for Apache Kafka](https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/aiven-tiered-storage) | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-filesystem`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-s3`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-gcs`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-azure` | [Upstream](https://github.com/Aiven-Open/tiered-storage-for-apache-kafka) |
| [Amazon MSK Library for AWS Identity and Access Management](https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/aws-msk-iam-auth) | `ghcr.io/oci-plugins-for-apache-kafka/aws-msk-iam-auth:2.3.7` | [Upstream](https://github.com/aws/aws-msk-iam-auth) |
| [Apache Camel Kafka Connect connectors](https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/camel-kafka-connectors) | `ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-bedrock-agent-runtime-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-bedrock-text-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-cloudtrail-source`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-cloudwatch-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-comprehend-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ddb-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ddb-streams-source`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ec2-sink`<br>... and 185 more | [Upstream](https://github.com/apache/camel-kafka-connector) |
| [Apache Kafka Connect File plugin](https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/connect-file) | `ghcr.io/oci-plugins-for-apache-kafka/connect-file:4.3.0` | [Upstream](https://github.com/apache/kafka) |

## Adding New Plugins

Open a pull request against the [catalog repository](https://github.com/oci-plugins-for-apache-kafka/catalog).
