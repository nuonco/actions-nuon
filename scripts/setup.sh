#!/usr/bin/env bash
# Shared Nuon CLI setup for the root action and the branch actions.
set -euo pipefail

version() {
  ARTIFACTS_BASE_URL="https://nuon-artifacts.s3.us-west-2.amazonaws.com/cli"

  # mirror install.sh's os/arch detection, so that we check for the exact
  # artifact the installer will reach for
  if command -v dpkg > /dev/null 2>&1; then
    ARCH=$(dpkg --print-architecture)
  else
    ARCH=$(uname -m)
  fi
  if [[ "$ARCH" == "x86_64" ]]; then
    ARCH=amd64
  fi
  OS=$(uname -s | awk '{print tolower($0)}')

  # succeeds when the release bucket holds a binary for the given version.
  # a 404 is an expected outcome here, so curl stays quiet about it
  published() {
    curl -fsI -o /dev/null "$ARTIFACTS_BASE_URL/$1/nuon_${OS}_${ARCH}.gz" ||
      curl -fsI -o /dev/null "$ARTIFACTS_BASE_URL/$1/nuon_${OS}_${ARCH}"
  }

  if [[ "$NUON_VERSION" == "" || "$NUON_VERSION" == "latest" ]]; then
    for attempt in 1 2 3; do
      echo "Fetching version from $NUON_API_URL (attempt $attempt/3)"
      NUON_VERSION=$(curl -fsS "$NUON_API_URL/version" | jq -r '.version')
      if [[ "$NUON_VERSION" != "" && "$NUON_VERSION" != "null" ]]; then
        break
      fi
      sleep 2
    done
    if [[ "$NUON_VERSION" == "" || "$NUON_VERSION" == "null" ]]; then
      echo "Failed to fetch nuon version from $NUON_API_URL after 3 attempts"
      exit 1
    fi
    echo "$NUON_API_URL reports version $NUON_VERSION"

    if published "$NUON_VERSION"; then
      echo "Found nuon $NUON_VERSION for ${OS}_${ARCH} in the release bucket"
    else
      LATEST=$(curl -fsS "$ARTIFACTS_BASE_URL/latest.txt" | tr -d '[:space:]')
      if [[ "$LATEST" == "" ]]; then
        echo "::error title=Nuon CLI version unavailable::nuon $NUON_VERSION is not published for ${OS}_${ARCH}, and $ARTIFACTS_BASE_URL/latest.txt could not be read to fall back."
        exit 1
      fi
      echo "::warning title=Nuon CLI version fallback::$NUON_API_URL reports version $NUON_VERSION, but no ${OS}_${ARCH} binary is published for it. Falling back to latest ($LATEST)."
      NUON_VERSION="$LATEST"
    fi
  fi
  echo "NUON_VERSION=$NUON_VERSION" >> "$GITHUB_ENV"
  echo "nuon_version=$NUON_VERSION" >> "$GITHUB_OUTPUT"
}

install() {
  local dest="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/install.sh"
  curl -fsSL https://nuon-artifacts.s3.us-west-2.amazonaws.com/cli/install.sh -o "$dest"
  bash "$dest" --no-input
  echo "installed nuon version $(nuon -j version)"
}

config() {
  echo "::group::Configuring Nuon CLI"
  NUON_CONFIG="$HOME/.nuon"

  cat > "$NUON_CONFIG" << EOF
api_url: ${NUON_API_URL}
org_id: ${NUON_ORG_ID}
EOF

  if [ -n "${NUON_API_TOKEN:-}" ]; then
    echo "api_token: ${NUON_API_TOKEN}" >> "$NUON_CONFIG"
  fi

  if [ -n "${NUON_APP_ID:-}" ]; then
    echo "app_id: ${NUON_APP_ID}" >> "$NUON_CONFIG"
  fi

  # set the env var so subsequent steps can use Nuon CLI
  # without needing to specify config file
  echo "NUON_CONFIG_FILE=$NUON_CONFIG" >> "$GITHUB_ENV"

  if [ -n "${NUON_OIDC_AUDIENCE:-}" ]; then
    echo "NUON_OIDC_AUDIENCE=${NUON_OIDC_AUDIENCE}" >> "$GITHUB_ENV"
  fi

  echo "Generated Nuon CLI config file at ${NUON_CONFIG}"
  echo "::endgroup::"
}

preflight() {
  echo "NUON_CONFIG_FILE=$NUON_CONFIG_FILE"
  # ensures the token is working and org exists
  nuon orgs get

  if [[ "${NUON_APP_ID:-}" != "" ]]; then
    nuon apps get
  fi
}

case "${1:-}" in
  version | install | config | preflight) "$1" ;;
  *)
    echo "usage: setup.sh version|install|config|preflight" >&2
    exit 1
    ;;
esac
