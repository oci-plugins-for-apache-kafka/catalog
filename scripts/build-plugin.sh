#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  build-plugin.sh <plugin> <version> [--image <image>] [--push]

Builds all image entries defined in plugins/<plugin>/versions/<version>.yaml.
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

normalize_root_path() {
  local path="$1"
  printf '%s' "${path#/}"
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual

  if [[ -z "$expected" ]]; then
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file")
    actual=${actual%% *}
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file")
    actual=${actual%% *}
  else
    printf 'ERROR: sha256 verification requested, but neither sha256sum nor shasum is available.\n' >&2
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    printf 'ERROR: checksum mismatch for %s\n' "$file" >&2
    printf 'Expected: %s\n' "$expected" >&2
    printf 'Actual:   %s\n' "$actual" >&2
    exit 1
  fi
}

download_artifact() {
  local url="$1"
  local output="$2"

  printf 'Downloading %s\n' "$url"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$output"
}

copy_artifact() {
  local source="$1"
  local rootfs="$2"
  local destination="$3"
  local relative_destination target parent

  relative_destination=$(normalize_root_path "$destination")
  target="$rootfs/$relative_destination"
  parent=${target%/*}

  mkdir -p "$parent"
  cp "$source" "$target"
}

extract_artifact() {
  local source="$1"
  local rootfs="$2"
  local destination="$3"
  local strip_components="$4"
  local relative_destination target

  relative_destination=$(normalize_root_path "$destination")
  if [[ -z "$relative_destination" ]]; then
    target="$rootfs"
  else
    target="$rootfs/$relative_destination"
  fi

  mkdir -p "$target"

  if [[ "$strip_components" -gt 0 ]]; then
    tar -xzf "$source" --strip-components="$strip_components" -C "$target"
  else
    tar -xzf "$source" -C "$target"
  fi
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

plugin="$1"
version="$2"
shift 2
push=false
selected_image=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      selected_image="${2:-}"
      shift 2
      ;;
    --push)
      push=true
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
require_command docker
require_command curl
require_command tar

plugin_file="plugins/$plugin/plugin.yaml"
version_file="plugins/$plugin/versions/$version.yaml"

if [[ ! -f "$plugin_file" ]]; then
  printf 'ERROR: plugin manifest not found: %s\n' "$plugin_file" >&2
  exit 1
fi

if [[ ! -f "$version_file" ]]; then
  printf 'ERROR: version manifest not found: %s\n' "$version_file" >&2
  exit 1
fi

repository=$(yaml_get '.image' "$plugin_file")
plugin_name=$(yaml_get '.name' "$plugin_file")
description=$(yaml_get '.description' "$plugin_file")
upstream=$(yaml_get '.upstream' "$plugin_file")
manifest_version=$(yaml_get '.version' "$version_file")
image_count=$(yaml_length '.images' "$version_file")
work_dir=$(mktemp -d)
matched_image=false

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

if [[ "$manifest_version" != "$version" ]]; then
  printf 'ERROR: %s has version %s, expected %s\n' "$version_file" "$manifest_version" "$version" >&2
  exit 1
fi

for ((image_index = 0; image_index < image_count; image_index++)); do
  image_prefix=".images[$image_index]"
  image_id=$(yaml_get "$image_prefix.id" "$version_file")

  if [[ -n "$selected_image" && "$image_id" != "$selected_image" ]]; then
    continue
  fi

  matched_image=true
  image_dir="$work_dir/$plugin-$version-$image_id-context"
  rootfs="$image_dir/rootfs"
  artifacts_dir="$work_dir/$plugin-$version-$image_id-artifacts"
  dockerfile="$image_dir/Dockerfile"
  artifact_count=$(yaml_length "$image_prefix.artifacts" "$version_file")
  tag_count=$(yaml_length "$image_prefix.tags" "$version_file")

  mkdir -p "$rootfs" "$artifacts_dir"

  printf 'Building %s %s image %s\n' "$plugin" "$version" "$image_id"

  for ((artifact_index = 0; artifact_index < artifact_count; artifact_index++)); do
    artifact_prefix="$image_prefix.artifacts[$artifact_index]"
    url=$(yaml_get "$artifact_prefix.url" "$version_file")
    sha256=$(yaml_get "$artifact_prefix.sha256" "$version_file")
    destination=$(yaml_get "$artifact_prefix.destination" "$version_file")
    extract_destination=$(yaml_get "$artifact_prefix.extract.destination" "$version_file")
    strip_components=$(yaml_get "$artifact_prefix.extract.stripComponents" "$version_file")
    artifact_file="$artifacts_dir/artifact-$artifact_index"

    if [[ -z "$strip_components" ]]; then
      strip_components=0
    fi

    download_artifact "$url" "$artifact_file"
    verify_sha256 "$artifact_file" "$sha256"

    if [[ -n "$extract_destination" ]]; then
      extract_artifact "$artifact_file" "$rootfs" "$extract_destination" "$strip_components"
    else
      copy_artifact "$artifact_file" "$rootfs" "$destination"
    fi
  done

  cat >"$dockerfile" <<'DOCKERFILE'
FROM scratch
COPY rootfs/ /
DOCKERFILE

  docker_args=(
    build
    --no-cache
    -f "$dockerfile"
    --label "org.opencontainers.image.source=https://github.com/oci-plugins-for-apache-kafka/catalog"
    --label "org.opencontainers.image.url=https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/$plugin"
    --label "org.opencontainers.image.version=$version"
    --label "org.opencontainers.image.title=$plugin_name"
    --label "org.opencontainers.image.description=$description"
    --label "org.opencontainers.image.vendor=oci-plugins-for-apache-kafka"
    --label "org.opencontainers.image.documentation=https://github.com/oci-plugins-for-apache-kafka/catalog/tree/main/plugins/$plugin"
    --label "org.oci-plugins-for-apache-kafka.upstream=$upstream"
  )

  tags=()
  for ((tag_index = 0; tag_index < tag_count; tag_index++)); do
    tag=$(yaml_get "$image_prefix.tags[$tag_index]" "$version_file")
    docker_args+=(-t "$repository:$tag")
    tags+=("$repository:$tag")
  done

  docker "${docker_args[@]}" "$image_dir"

  if [[ "$push" == true ]]; then
    for tag in "${tags[@]}"; do
      docker push "$tag"
    done
  fi
done

if [[ -n "$selected_image" && "$matched_image" == false ]]; then
  printf 'ERROR: image %s not found in %s\n' "$selected_image" "$version_file" >&2
  exit 1
fi
