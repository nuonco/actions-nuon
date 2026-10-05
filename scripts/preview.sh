#!/usr/bin/env bash
# Entrypoints for `nuon branches preview`.
#
# The source flag is fixed inside each function: --pr-number or --git-ref.
set -euo pipefail

usage() {
  echo "usage: preview.sh pr|git-ref" >&2
  exit 1
}

require_branch() {
  if [[ -z "${NUON_BRANCH_ID:-}" ]]; then
    echo "::error title=Missing branch_id::branch_id is required to preview a branch run."
    exit 1
  fi
}

validate_mode() {
  case "${NUON_PREVIEW_MODE:-}" in
    "" | plan-only | apply | build-only) ;;
    *)
      echo "::error title=Invalid preview mode::mode must be plan-only, apply, or build-only (got: ${NUON_PREVIEW_MODE})."
      exit 1
      ;;
  esac
}

# Source flags are the remaining arguments (for example --pr-number 42).
run_preview() {
  require_branch
  validate_mode

  local -a cmd=(
    nuon branches preview
    --branch-id "$NUON_BRANCH_ID"
    "$@"
    --output json
  )
  if [[ -n "${NUON_PREVIEW_MODE:-}" ]]; then
    cmd+=(--mode "$NUON_PREVIEW_MODE")
  fi
  if [[ -n "${NUON_INSTALL_ID:-}" ]]; then
    cmd+=(--install-id "$NUON_INSTALL_ID")
  fi
  if [[ -n "${NUON_HEAD_SHA:-}" ]]; then
    cmd+=(--head-sha "$NUON_HEAD_SHA")
  fi
  if [[ -n "${NUON_CONFIG_ID:-}" ]]; then
    cmd+=(--config-id "$NUON_CONFIG_ID")
  fi
  if [[ -n "${NUON_APP_ID:-}" ]]; then
    cmd+=(--app-id "$NUON_APP_ID")
  fi
  if [[ "${NUON_FORCE:-false}" == "true" ]]; then
    cmd+=(--force)
  fi
  if [[ "${NUON_AUTO_APPROVE:-false}" == "true" ]]; then
    cmd+=(--auto-approve)
  fi
  if [[ "${NUON_WAIT:-false}" == "true" ]]; then
    cmd+=(--wait)
  elif [[ "${NUON_NO_WAIT:-true}" != "false" ]]; then
    cmd+=(--no-wait)
  fi

  local line="" arg
  for arg in "${cmd[@]}"; do
    line+=$(printf ' %q' "$arg")
  done
  echo "Running:${line}"
  "${cmd[@]}"
}

preview_pr() {
  if [[ -z "${NUON_PR_NUMBER:-}" ]]; then
    echo "::error title=Missing pr_number::pr_number is required."
    exit 1
  fi
  if ! [[ "$NUON_PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error title=Invalid pull request::pr_number must be a positive integer (got: ${NUON_PR_NUMBER})."
    exit 1
  fi
  run_preview --pr-number "$NUON_PR_NUMBER"
}

preview_git_ref() {
  if [[ -z "${NUON_GIT_REF:-}" ]]; then
    echo "::error title=Missing git_ref::git_ref is required."
    exit 1
  fi
  run_preview --git-ref "$NUON_GIT_REF"
}

case "${1:-}" in
  pr) preview_pr ;;
  git-ref) preview_git_ref ;;
  *) usage ;;
esac
