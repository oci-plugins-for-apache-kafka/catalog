# OCI Plugins for Apache Kafka Catalog

This repository contains the catalog and build automation for OCI artifacts with Apache Kafka plugins.
The artifacts are intended for Kubernetes image volume use cases, such as mounting plugins into Strimzi-managed Apache Kafka deployments without building a custom Kafka image.

This organization is not part of the Apache Kafka project.

## Current Plugins

| Plugin | Description | Images | Upstream |
|---|---|---|---|
| [Aiven Tiered Storage plugins for Apache Kafka](plugins/aiven-tiered-storage/) | OCI artifacts with the Aiven tiered storage plugins for Apache Kafka. | `ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-filesystem`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-s3`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-gcs`<br>`ghcr.io/oci-plugins-for-apache-kafka/aiven-tiered-storage:1.1.1-azure` | [Upstream](https://github.com/Aiven-Open/tiered-storage-for-apache-kafka) |
| [Amazon MSK Library for AWS Identity and Access Management](plugins/aws-msk-iam-auth/) | OCI artifacts with the Amazon MSK Library for AWS Identity and Access Management. | `ghcr.io/oci-plugins-for-apache-kafka/aws-msk-iam-auth:2.3.7` | [Upstream](https://github.com/aws/aws-msk-iam-auth) |
| [Apache Camel Kafka Connect connectors](plugins/camel-kafka-connectors/) | OCI artifacts with Apache Camel Kafka Connect connector packages. | `ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-bedrock-agent-runtime-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-bedrock-text-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-cloudtrail-source`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-cloudwatch-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-comprehend-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ddb-sink`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ddb-streams-source`<br>`ghcr.io/oci-plugins-for-apache-kafka/camel-kafka-connectors:4.18.0-aws-ec2-sink`<br>... and 185 more | [Upstream](https://github.com/apache/camel-kafka-connector) |
| [Apache Kafka Connect File plugin](plugins/connect-file/) | OCI artifacts with the Apache Kafka Connect File plugin. | `ghcr.io/oci-plugins-for-apache-kafka/connect-file:4.3.0` | [Upstream](https://github.com/apache/kafka) |
| [Debezium connectors](plugins/debezium-connectors/) | OCI artifacts with Debezium Kafka Connect connector plugin packages. | `ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-cassandra-3`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-cassandra-4`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-cassandra-5`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-cockroachdb`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-db2`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-dse`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-ibmi`<br>`ghcr.io/oci-plugins-for-apache-kafka/debezium-connectors:3.5.2.Final-informix`<br>... and 10 more | [Upstream](https://github.com/debezium/debezium) |
| [Kafka Connect plugin which logs messages into log](plugins/echo-sink/) | OCI artifacts with the Echo Sink plugin. | `ghcr.io/oci-plugins-for-apache-kafka/echo-sink:1.6.0` | [Upstream](https://github.com/scholzj/echo-sink) |

## Catalog Model

Each plugin has stable metadata in `plugins/<plugin>/plugin.yaml` and one immutable manifest per upstream version in `plugins/<plugin>/versions/<version>.yaml`.

`plugin.yaml` defines plugin-level metadata:

```yaml
id: aws-msk-iam-auth
name: Amazon MSK Library for AWS Identity and Access Management
description: OCI artifacts with the Amazon MSK Library for AWS Identity and Access Management.
upstream: https://github.com/aws/aws-msk-iam-auth
image: ghcr.io/oci-plugins-for-apache-kafka/aws-msk-iam-auth
```

`versions/<version>.yaml` defines the build inputs and tags for that upstream version:

```yaml
version: 2.3.5
images:
  - id: default
    tags:
      - 2.3.5
    artifacts:
      - url: https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.5/aws-msk-iam-auth-2.3.5-all.jar
        destination: /aws-msk-iam-auth-2.3.5-all.jar
```

Multi-image plugin versions use the same structure with more entries under `images`.

## Adding a Plugin

1. Copy `templates/plugin.yaml` to `plugins/<plugin>/plugin.yaml`.
2. Copy `templates/version.yaml` to `plugins/<plugin>/versions/<version>.yaml`.
3. Fill in the plugin metadata, artifact URLs, destinations, extraction settings, and image tags.
4. Add a short `plugins/<plugin>/README.md` with usage notes and examples.
5. Run `bash scripts/render-readmes.sh` to update generated documentation.
6. Run `bash scripts/validate-catalog.sh`.
7. Run `bash scripts/render-readmes.sh --check` to verify generated documentation is current.

Checksums are optional. If an artifact has a `sha256` field, the build script verifies it. If the field is omitted, the artifact is downloaded without checksum validation.

## Build Detection

The rebuild unit is a version manifest.

| Changed file | Build behavior |
|---|---|
| `plugins/<plugin>/versions/<version>.yaml` | Build only that plugin version. |
| `plugins/<plugin>/plugin.yaml` | Build all versions for that plugin. |
| `scripts/build-plugin.sh` | Build all versions. |
| `.github/workflows/build.yaml` | Build all versions. |
| `templates/*` | Build all versions. |
| Documentation and examples | No image build. |

Pull requests build affected images but do not push them.
Pushes to `main` build affected images and push them to `ghcr.io/oci-plugins-for-apache-kafka`.

## Local Requirements

The catalog scripts use Bash and Mike Farah `yq` v4.

On macOS:

```bash
brew install yq
```

For local image builds, Docker, `curl`, and `tar` are also required.

## Useful Commands

Validate the catalog:

```bash
bash scripts/validate-catalog.sh
```

Render generated documentation:

```bash
bash scripts/render-readmes.sh
```

Check generated documentation without writing files:

```bash
bash scripts/render-readmes.sh --check
```

Detect changed build targets between two Git commits:

```bash
bash scripts/detect-changes.sh --base origin/main --head HEAD
```

Build one plugin version locally:

```bash
bash scripts/build-plugin.sh aws-msk-iam-auth 2.3.5
```
