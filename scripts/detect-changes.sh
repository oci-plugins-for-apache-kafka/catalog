#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

usage() {
  cat <<'USAGE' >&2
Usage:
  detect-changes.sh --base <ref> --head <ref>
  detect-changes.sh --all
  detect-changes.sh --plugin <plugin> [--version <version>]

Outputs a GitHub Actions matrix as compact JSON.
USAGE
}

pairs_file=$(mktemp)
sorted_file=$(mktemp)
changed_files_file=$(mktemp)

cleanup() {
  rm -f "$pairs_file" "$sorted_file" "$changed_files_file"
}
trap cleanup EXIT

base_ref=""
head_ref=""
plugin=""
version=""
all=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base_ref="${2:-}"
      shift 2
      ;;
    --head)
      head_ref="${2:-}"
      shift 2
      ;;
    --plugin)
      plugin="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
      shift 2
      ;;
    --all)
      all=true
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

add_pair() {
  local pair_plugin="$1"
  local pair_version="$2"
  local version_file="plugins/$pair_plugin/versions/$pair_version.yaml"

  if [[ ! -f "$version_file" ]]; then
    printf 'ERROR: version manifest not found: %s\n' "$version_file" >&2
    exit 1
  fi

  printf '%s\t%s\n' "$pair_plugin" "$pair_version" >>"$pairs_file"
}

add_plugin_versions() {
  local pair_plugin="$1"
  local version_files=("plugins/$pair_plugin"/versions/*.yaml)

  if [[ ${#version_files[@]} -eq 0 ]]; then
    printf 'ERROR: no versions found for plugin: %s\n' "$pair_plugin" >&2
    exit 1
  fi

  local version_file
  for version_file in "${version_files[@]}"; do
    add_pair "$pair_plugin" "$(basename "$version_file" .yaml)"
  done
}

add_all_versions() {
  local version_files=(plugins/*/versions/*.yaml)
  local version_file pair_plugin pair_version

  for version_file in "${version_files[@]}"; do
    pair_plugin=$(basename "$(dirname "$(dirname "$version_file")")")
    pair_version=$(basename "$version_file" .yaml)
    add_pair "$pair_plugin" "$pair_version"
  done
}

detect_from_diff() {
  git diff --name-only "$base_ref" "$head_ref" >"$changed_files_file"

  local path root plugin_dir second third rest version_name
  while IFS= read -r path; do
    case "$path" in
      plugins/*/versions/*.yaml)
        IFS='/' read -r root plugin_dir second third rest <<<"$path"
        if [[ "$root" == 'plugins' && "$second" == 'versions' && -z "${rest:-}" ]]; then
          version_name=$(basename "$third" .yaml)
          if [[ -f "plugins/$plugin_dir/versions/$version_name.yaml" ]]; then
            add_pair "$plugin_dir" "$version_name"
          fi
        fi
        ;;
      plugins/*/plugin.yaml)
        IFS='/' read -r root plugin_dir second rest <<<"$path"
        if [[ "$root" == 'plugins' && "$second" == 'plugin.yaml' && -z "${rest:-}" ]]; then
          if [[ -d "plugins/$plugin_dir/versions" ]]; then
            add_plugin_versions "$plugin_dir"
          fi
        fi
        ;;
      scripts/build-plugin.sh|.github/workflows/build.yaml|.github/workflows/build.yml|templates/*)
        add_all_versions
        ;;
    esac
  done <"$changed_files_file"
}

write_matrix() {
  sort -u "$pairs_file" >"$sorted_file"

  if [[ ! -s "$sorted_file" ]]; then
    printf '{"include":[]}\n'
    return
  fi

  local first=true
  local pair_plugin pair_version

  printf '{"include":['
  while IFS=$'\t' read -r pair_plugin pair_version; do
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ','
    fi
    printf '{"plugin":"%s","version":"%s"}' "$pair_plugin" "$pair_version"
  done <"$sorted_file"
  printf ']}\n'
}

if [[ "$all" == true ]]; then
  add_all_versions
elif [[ -n "$plugin" ]]; then
  if [[ -n "$version" ]]; then
    add_pair "$plugin" "$version"
  else
    add_plugin_versions "$plugin"
  fi
else
  if [[ -z "$base_ref" || -z "$head_ref" ]]; then
    usage
    exit 1
  fi
  detect_from_diff
fi

write_matrix
