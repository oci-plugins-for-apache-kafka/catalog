#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

failures=0
plugin_ids_file=$(mktemp)
tags_file=$(mktemp)

cleanup() {
  rm -f "$plugin_ids_file" "$tags_file"
}
trap cleanup EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  failures=$((failures + 1))
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

is_identifier() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

is_sha256() {
  [[ "$1" =~ ^[A-Fa-f0-9]{64}$ ]]
}

validate_yaml_file() {
  local file="$1"

  if ! yq e '.' "$file" >/dev/null; then
    fail "$file is not valid YAML"
    return 1
  fi
}

validate_plugin() {
  local plugin_dir="$1"
  local plugin_file="$plugin_dir/plugin.yaml"
  local plugin_name
  plugin_name=$(basename "$plugin_dir")

  if [[ ! -f "$plugin_file" ]]; then
    fail "$plugin_dir is missing plugin.yaml"
    return
  fi

  validate_yaml_file "$plugin_file" || return

  local id name description upstream image
  id=$(yaml_get '.id' "$plugin_file")
  name=$(yaml_get '.name' "$plugin_file")
  description=$(yaml_get '.description' "$plugin_file")
  upstream=$(yaml_get '.upstream' "$plugin_file")
  image=$(yaml_get '.image' "$plugin_file")

  if [[ -z "$id" ]]; then
    fail "$plugin_file must define .id"
  elif [[ "$id" != "$plugin_name" ]]; then
    fail "$plugin_file .id must match directory name '$plugin_name'"
  elif ! is_identifier "$id"; then
    fail "$plugin_file .id contains invalid characters: $id"
  fi

  if [[ -n "$id" ]]; then
    if grep -Fxq "$id" "$plugin_ids_file"; then
      fail "duplicate plugin id: $id"
    else
      printf '%s\n' "$id" >>"$plugin_ids_file"
    fi
  fi

  if [[ -z "$name" ]]; then
    fail "$plugin_file must define .name"
  fi

  if [[ -z "$description" ]]; then
    fail "$plugin_file must define .description"
  fi

  if [[ ! "$upstream" =~ ^https:// ]]; then
    fail "$plugin_file .upstream must be an https URL"
  fi

  if [[ ! "$image" =~ ^ghcr\.io/oci-plugins-for-apache-kafka/[a-z0-9][a-z0-9._/-]*$ ]]; then
    fail "$plugin_file .image must use ghcr.io/oci-plugins-for-apache-kafka/..."
  fi

  local version_files=("$plugin_dir"/versions/*.yaml)
  if [[ ${#version_files[@]} -eq 0 ]]; then
    fail "$plugin_dir must contain at least one versions/*.yaml file"
    return
  fi

  local version_file
  for version_file in "${version_files[@]}"; do
    validate_version "$plugin_file" "$version_file"
  done
}

validate_version() {
  local plugin_file="$1"
  local version_file="$2"

  validate_yaml_file "$version_file" || return

  local repository version expected_version image_count
  repository=$(yaml_get '.image' "$plugin_file")
  version=$(yaml_get '.version' "$version_file")
  expected_version=$(basename "$version_file" .yaml)
  image_count=$(yaml_length '.images' "$version_file")

  if [[ -z "$version" ]]; then
    fail "$version_file must define .version"
  elif [[ "$version" != "$expected_version" ]]; then
    fail "$version_file .version must match filename '$expected_version'"
  fi

  if [[ ! "$image_count" =~ ^[0-9]+$ ]] || [[ "$image_count" -eq 0 ]]; then
    fail "$version_file must define at least one image in .images"
    return
  fi

  local image_index
  for ((image_index = 0; image_index < image_count; image_index++)); do
    validate_image "$repository" "$version_file" "$image_index"
  done
}

validate_image() {
  local repository="$1"
  local version_file="$2"
  local image_index="$3"
  local image_prefix=".images[$image_index]"
  local image_id tag_count artifact_count

  image_id=$(yaml_get "$image_prefix.id" "$version_file")
  tag_count=$(yaml_length "$image_prefix.tags" "$version_file")
  artifact_count=$(yaml_length "$image_prefix.artifacts" "$version_file")

  if [[ -z "$image_id" ]]; then
    fail "$version_file image[$image_index] must define .id"
  elif ! is_identifier "$image_id"; then
    fail "$version_file image[$image_index].id contains invalid characters: $image_id"
  fi

  if [[ ! "$tag_count" =~ ^[0-9]+$ ]] || [[ "$tag_count" -eq 0 ]]; then
    fail "$version_file image[$image_index] must define at least one tag"
  fi

  local tag_index
  for ((tag_index = 0; tag_index < tag_count; tag_index++)); do
    local tag tag_key
    tag=$(yaml_get "$image_prefix.tags[$tag_index]" "$version_file")
    tag_key="$repository:$tag"

    if [[ -z "$tag" ]]; then
      fail "$version_file image[$image_index].tags[$tag_index] must not be empty"
    elif [[ ! "$tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
      fail "$version_file image[$image_index].tags[$tag_index] is not a valid Docker tag: $tag"
    elif grep -Fxq "$tag_key" "$tags_file"; then
      fail "duplicate image tag: $tag_key"
    else
      printf '%s\n' "$tag_key" >>"$tags_file"
    fi
  done

  if [[ ! "$artifact_count" =~ ^[0-9]+$ ]] || [[ "$artifact_count" -eq 0 ]]; then
    fail "$version_file image[$image_index] must define at least one artifact"
    return
  fi

  local artifact_index
  for ((artifact_index = 0; artifact_index < artifact_count; artifact_index++)); do
    validate_artifact "$version_file" "$image_index" "$artifact_index"
  done
}

validate_artifact() {
  local version_file="$1"
  local image_index="$2"
  local artifact_index="$3"
  local artifact_prefix=".images[$image_index].artifacts[$artifact_index]"
  local url destination extract_destination strip_components sha256

  url=$(yaml_get "$artifact_prefix.url" "$version_file")
  destination=$(yaml_get "$artifact_prefix.destination" "$version_file")
  extract_destination=$(yaml_get "$artifact_prefix.extract.destination" "$version_file")
  strip_components=$(yaml_get "$artifact_prefix.extract.stripComponents" "$version_file")
  sha256=$(yaml_get "$artifact_prefix.sha256" "$version_file")

  if [[ ! "$url" =~ ^https:// ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index].url must be an https URL"
  fi

  if [[ -n "$destination" && -n "$extract_destination" ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index] must use either destination or extract.destination, not both"
  elif [[ -z "$destination" && -z "$extract_destination" ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index] must define destination or extract.destination"
  fi

  if [[ -n "$destination" && ! "$destination" =~ ^/ ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index].destination must be absolute"
  fi

  if [[ -n "$extract_destination" && ! "$extract_destination" =~ ^/ ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index].extract.destination must be absolute"
  fi

  if [[ -n "$strip_components" && ! "$strip_components" =~ ^[0-9]+$ ]]; then
    fail "$version_file image[$image_index].artifacts[$artifact_index].extract.stripComponents must be a non-negative integer"
  fi

  if [[ -n "$sha256" ]] && ! is_sha256 "$sha256"; then
    fail "$version_file image[$image_index].artifacts[$artifact_index].sha256 must be a 64 character hex string"
  fi
}

require_command yq

case "$(yq --version)" in
  *'version v4'*|*'version 4'*) ;;
  *)
    printf 'ERROR: Mike Farah yq v4 is required. Found: %s\n' "$(yq --version)" >&2
    exit 1
    ;;
esac

plugin_dirs=(plugins/*)
if [[ ${#plugin_dirs[@]} -eq 0 ]]; then
  fail 'no plugins found under plugins/'
fi

for plugin_dir in "${plugin_dirs[@]}"; do
  if [[ -d "$plugin_dir" ]]; then
    validate_plugin "$plugin_dir"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  printf 'Catalog validation failed with %s error(s).\n' "$failures" >&2
  exit 1
fi

printf 'Catalog validation passed.\n'
