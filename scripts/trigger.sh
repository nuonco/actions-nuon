#!/usr/bin/env bash
# Entrypoints for `nuon branches trigger`.
#
# --run-type and --run-ref are fixed inside each function so workflow authors
# pass a tag, commit, or pull request instead of those flags.
set -euo pipefail

usage() {
  echo "usage: trigger.sh tag|commit|pr" >&2
  exit 1
}

require_branch() {
  if [[ -z "${NUON_BRANCH_ID:-}" ]]; then
    echo "::error title=Missing branch_id::branch_id is required to trigger a branch run."
    exit 1
  fi
}

require_ref() {
  local label="$1"
  if [[ -z "${NUON_RUN_REF:-}" ]]; then
    echo "::error title=Missing ref::${label} is required."
    exit 1
  fi
}

run_trigger() {
  local run_type="$1"
  require_branch

  local -a cmd=(
    nuon branches trigger
    --branch-id "$NUON_BRANCH_ID"
    --run-type "$run_type"
    --run-ref "$NUON_RUN_REF"
    --output json
  )
  if [[ -n "${NUON_APP_ID:-}" ]]; then
    cmd+=(--app-id "$NUON_APP_ID")
  fi
  if [[ "${NUON_FORCE:-false}" == "true" ]]; then
    cmd+=(--force)
  fi
  if [[ "${NUON_NO_WAIT:-true}" != "false" ]]; then
    cmd+=(--no-wait)
  fi

  local line="" arg
  for arg in "${cmd[@]}"; do
    line+=$(printf ' %q' "$arg")
  done
  echo "Running:${line}"
  "${cmd[@]}"
}

trigger_tag() {
  require_ref "tag"
  run_trigger tag
}

trigger_commit() {
  require_ref "sha"
  run_trigger commit
}

trigger_pr() {
  require_ref "pr_number"
  if ! [[ "$NUON_RUN_REF" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error title=Invalid pull request::pr_number must be a positive integer (got: ${NUON_RUN_REF})."
    exit 1
  fi
  run_trigger pr
}

case "${1:-}" in
  tag) trigger_tag ;;
  commit) trigger_commit ;;
  pr) trigger_pr ;;
  *) usage ;;
esac
