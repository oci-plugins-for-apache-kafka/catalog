#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

usage() {
  cat <<'USAGE' >&2
Usage:
  render-readmes.sh [--check]

Renders README.md and docs/profile.md from the catalog metadata.
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

yaml_get() {
  yq e "$1 // \"\"" "$2"
}

yaml_length() {
  yq e "$1 // [] | length" "$2"
}

escape_markdown_table_cell() {
  local value="$1"
  value=${value//|/\\|}
  printf '%s' "$value"
}

image_list_for_plugin() {
  local plugin="$1"
  local plugin_file="plugins/$plugin/plugin.yaml"
  local repository
  repository=$(yaml_get '.image' "$plugin_file")

  local first=true
  local limit=8
  local count=0
  local total=0
  local version_file image_count image_index tag_count tag_index tag

  for version_file in "plugins/$plugin"/versions/*.yaml; do
    image_count=$(yaml_length '.images' "$version_file")
    for ((image_index = 0; image_index < image_count; image_index++)); do
      tag_count=$(yaml_length ".images[$image_index].tags" "$version_file")
      total=$((total + tag_count))
    done
  done

  for version_file in "plugins/$plugin"/versions/*.yaml; do
    image_count=$(yaml_length '.images' "$version_file")
    for ((image_index = 0; image_index < image_count; image_index++)); do
      tag_count=$(yaml_length ".images[$image_index].tags" "$version_file")
      for ((tag_index = 0; tag_index < tag_count; tag_index++)); do
        if [[ "$count" -ge "$limit" ]]; then
          continue
        fi
        tag=$(yaml_get ".images[$image_index].tags[$tag_index]" "$version_file")
        if [[ "$first" == true ]]; then
          first=false
        else
          printf '<br>'
        fi
        printf '`%s:%s`' "$repository" "$tag"
        count=$((count + 1))
      done
    done
  done

  if [[ "$total" -gt "$limit" ]]; then
    printf '<br>... and %s more' "$((total - limit))"
  fi
}

render_catalog_table() {
  local link_prefix="$1"
  local plugin_file plugin name description upstream images

  printf '| Plugin | Description | Images | Upstream |\n'
  printf '|---|---|---|---|\n'

  for plugin_file in plugins/*/plugin.yaml; do
    plugin=$(basename "$(dirname "$plugin_file")")
    name=$(escape_markdown_table_cell "$(yaml_get '.name' "$plugin_file")")
    description=$(escape_markdown_table_cell "$(yaml_get '.description' "$plugin_file")")
    upstream=$(yaml_get '.upstream' "$plugin_file")
    images=$(image_list_for_plugin "$plugin")

    printf '| [%s](%s%s/) | %s | %s | [Upstream](%s) |\n' "$name" "$link_prefix" "$plugin" "$description" "$images" "$upstream"
  done
}

render_profile_table() {
  local plugin_file plugin name upstream images

  printf '| Plugin | Images | Upstream |\n'
  printf '|---|---|---|\n'

  for plugin_file in plugins/*/plugin.yaml; do
    plugin=$(basename "$(dirname "$plugin_file")")
    name=$(escape_markdown_table_cell "$(yaml_get '.name' "$plugin_file")")
    upstream=$(yaml_get '.upstream' "$plugin_file")
    images=$(image_list_for_plugin "$plugin")

    printf '| [%s](https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/%s) | %s | [Upstream](%s) |\n' "$name" "$plugin" "$images" "$upstream"
  done
}

render_readme() {
  local output="$1"

  {
    cat <<'EOF'
# OCI Plugins for Apache Kafka Catalog

This repository contains the catalog and build automation for OCI artifacts with Apache Kafka plugins.
The artifacts are intended for Kubernetes image volume use cases, such as mounting plugins into Strimzi-managed Apache Kafka deployments without building a custom Kafka image.

This organization is not part of the Apache Kafka project.

## Current Plugins

EOF
    render_catalog_table 'plugins/'
    cat <<'EOF'

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
EOF
  } >"$output"
}

render_profile() {
  local output="$1"

  {
    cat <<'EOF'
# OCI Plugins for Apache Kafka

This organization contains OCI artifacts with Apache Kafka plugins.
The artifacts can be mounted into Kubernetes workloads as image volumes, avoiding custom container images for common plugin use cases.

This organization is not part of the Apache Kafka project.

## Currently Supported Plugins

EOF
    render_profile_table
    cat <<'EOF'

## Adding New Plugins

Open a pull request against the [catalog repository](https://github.com/oci-plugins-for-apache-kafka/catalog).
EOF
  } >"$output"
}

check=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command yq

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$tmp_dir/docs"
render_readme "$tmp_dir/README.md"
render_profile "$tmp_dir/docs/profile.md"

if [[ "$check" == true ]]; then
  failed=false

  if ! cmp -s "$tmp_dir/README.md" README.md; then
    printf 'ERROR: README.md is not up to date. Run bash scripts/render-readmes.sh.\n' >&2
    diff -u README.md "$tmp_dir/README.md" >&2 || true
    failed=true
  fi

  if ! cmp -s "$tmp_dir/docs/profile.md" docs/profile.md; then
    printf 'ERROR: docs/profile.md is not up to date. Run bash scripts/render-readmes.sh.\n' >&2
    diff -u docs/profile.md "$tmp_dir/docs/profile.md" >&2 || true
    failed=true
  fi

  if [[ "$failed" == true ]]; then
    exit 1
  fi

  printf 'Generated documentation is up to date.\n'
  exit 0
fi

mkdir -p docs
cp "$tmp_dir/README.md" README.md
cp "$tmp_dir/docs/profile.md" docs/profile.md
printf 'Rendered README.md and docs/profile.md.\n'
