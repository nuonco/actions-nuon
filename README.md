# Nuon GitHub Action

A GitHub Action for running [Nuon CLI](PLACEHOLDER_NUON_CLI_DOCS_URL) commands in your CI/CD workflows.

## Overview

This action installs the Nuon CLI, configures authentication, and executes arbitrary Nuon commands. It's designed to
integrate Nuon's infrastructure management capabilities directly into your GitHub Actions workflows.

## Authentication

The action authenticates with Nuon in one of two ways.

### OIDC federation (recommended)

GitHub Actions is an OIDC issuer, so the action can authenticate without any stored secret. When `api_token` is omitted,
the Nuon CLI detects the ambient GitHub Actions token and exchanges it for a short-lived org token automatically.

First, create a trust policy for your repository once — from the Dashboard (**Connections → your GitHub connection →
Manage OIDC**, which prefills the issuer, audience, and `sub`), or with the CLI. See the
[OIDC federation docs](https://docs.nuon.co/concepts/oidc-federation) for details.

The action requests an OIDC token whose audience defaults to `api_url` (`https://api.nuon.co`), which must match your
trust policy's audience. If your policy uses a different audience, set the `oidc_audience` input to override it.

Then grant the job permission to request an OIDC token and omit `api_token`:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Nuon command
        uses: nuonco/actions-nuon@v1
        with:
          org_id: ${{ vars.NUON_ORG_ID }}
          command: 'orgs current'
```

### API token

If you can't use OIDC, pass a long-lived [API token](https://docs.nuon.co/concepts/api-tokens) stored as a repository
secret via `api_token` (see the examples below).

## Usage

### Basic Example

```yaml
- name: Run Nuon command
  uses: nuonco/actions-nuon@v1
  with:
    org_id: ${{ secrets.NUON_ORG_ID }}
    api_token: ${{ secrets.NUON_API_TOKEN }}
    command: 'orgs current'
```

### Complete Example

```yaml
name: Nuon Apps Sync
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Sync with Nuon
        uses: nuonco/actions-nuon@v1
        with:
          org_id: ${{ secrets.NUON_ORG_ID }}
          api_token: ${{ secrets.NUON_API_TOKEN }}
          app_id: ${{ secrets.NUON_APP_ID }}
          command: 'apps sync .'
```

### Using the CLI directly

```yaml
name: Nuon Apps Sync
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Nuon CLI
        uses: nuonco/actions-nuon@v1
        with:
          org_id: ${{ secrets.NUON_ORG_ID }}
          api_token: ${{ secrets.NUON_API_TOKEN }}
          app_id: ${{ secrets.NUON_APP_ID }}

      - name: List all Installs
        run: |
          nuon installs list

      - name: Sync Install Configs
        run: |
          nuon installs sync -d example-app/installs
```

## Inputs

| Input           | Description                                                                           | Required | Default                |
| --------------- | ------------------------------------------------------------------------------------- | -------- | ---------------------- |
| `org_id`        | Your Nuon organization ID                                                             | Yes      | -                      |
| `api_token`     | Your Nuon API token. Omit to authenticate with OIDC federation.                       | No       | -                      |
| `app_id`        | The Nuon App ID for the config file                                                   | No       | -                      |
| `api_url`       | The URL of the Nuon API                                                               | No       | `https://api.nuon.co`  |
| `oidc_audience` | OIDC token audience. Set only if your trust policy's audience differs from `api_url`. | No       | `api_url`              |
| `nuon_version`  | Version of the Nuon CLI to use. If none is provided we'll use the api to choose.      | No       | `/version` or `latest` |
| `command`       | The Nuon CLI command to execute                                                       | No       | -                      |

## Outputs

| Output         | Description                                           |
| -------------- | ----------------------------------------------------- |
| `nuon_version` | The version of the CLI that was used for this command |

## How It Works

The action performs the following steps:

1. **Version Resolution**: Determines which version of the Nuon CLI to install using the provided `nuon_version` value
   if provided; otherwise, it will fetch the version from `https://$api_url/version`.
2. **Installation**: Downloads and installs the Nuon CLI
3. **Configuration**: Creates a `.nuon` config file with your credentials
4. **Preflight**: Validates authentication and configuration
5. **Execution**: Runs the Nuon command if specified

### Notes

1. if any `NUON_` envs are provided to a specific step for an action, these will override the values in the config.
1. the CLI is available for use in the steps that follow this action's run.

## App branches

Dedicated actions for `nuon branches trigger` and `nuon branches preview`. They run the same version, install, config,
and preflight steps, then execute the Nuon command.

| Action | Command |
| ------ | ------- |
| `branches/trigger/tag` | `nuon branches trigger --run-type tag` |
| `branches/trigger/commit` | `nuon branches trigger --run-type commit` |
| `branches/trigger/pr` | `nuon branches trigger --run-type pr` |
| `branches/preview/pr` | `nuon branches preview --pr-number` |
| `branches/preview/git-ref` | `nuon branches preview --git-ref` |

```yaml
- uses: nuonco/actions-nuon/branches/trigger/tag@v1
  with:
    org_id: ${{ vars.NUON_ORG_ID }}
    app_id: ${{ vars.NUON_APP_ID }}
    branch_id: production
    tag: ${{ github.ref_name }}

- uses: nuonco/actions-nuon/branches/preview/pr@v1
  with:
    org_id: ${{ vars.NUON_ORG_ID }}
    app_id: ${{ vars.NUON_APP_ID }}
    branch_id: preview
    pr_number: ${{ github.event.pull_request.number }}
    mode: plan-only
    install_id: ${{ vars.NUON_INSTALL_ID }}
```

Trigger actions take `tag`, `sha`, or `pr_number`. Preview actions take `pr_number` or `git_ref`, plus optional `mode`
(`plan-only`, `apply`, `build-only`), `install_id`, `head_sha`, `config_id`, `auto_approve`, and `wait`. `no_wait`
defaults to `true`. `wait: true` passes `--wait` instead.

## Security Best Practices

- **Prefer OIDC**: Authenticate with [OIDC federation](https://docs.nuon.co/concepts/oidc-federation) instead of a
  stored token when possible — there is no secret to leak or rotate.
- **Never commit secrets**: If you do use `api_token`, always store it as a GitHub Secret — never inline it.
- **Limit permissions**: Grant the minimum necessary role to your Nuon API tokens and trust policies.

Learn more about
[GitHub Actions security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).

## Common Commands

### Deploy an Install

```yaml
- uses: nuonco/actions-nuon@v1
  with:
    org_id: ${{ secrets.NUON_ORG_ID }}
    api_token: ${{ secrets.NUON_API_TOKEN }}
    app_id: ${{ secrets.NUON_APP_ID }}
    command: 'installs deploy --install-id ${{ secrets.INSTALL_ID }}'
```

### List Apps

```yaml
- uses: nuonco/actions-nuon@v1
  with:
    org_id: ${{ secrets.NUON_ORG_ID }}
    api_token: ${{ secrets.NUON_API_TOKEN }}
    command: 'apps list'
```

## Environment Variables

The action automatically sets up environment variables that can be referenced in your command:

- `NUON_CONFIG_FILE`: Path to the generated config file
- `NUON_VERSION`: The CLI version being used

## Troubleshooting

### Authentication Errors

If you encounter authentication errors, verify:

- Your `api_token` is valid and not expired (e.g. a personal token expires faster than a service account token).
- Your `org_id` is correct and the secret has access to that org.

### Command Failures

If a command fails, try running it locally to ensure it is valid.

## Docs

- [Nuon Documentation](https://docs.nuon.co)
- [Nuon CLI Reference](https://docs.nuon.co/cli)
- [Nuon API Documentation](https://docs.nuon.co/nuon-api)
- [Getting Started with Nuon](https://docs.nuon.co/get-started/quickstart)
