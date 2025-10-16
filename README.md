# Nuon GitHub Action

A GitHub Action for running [Nuon CLI](PLACEHOLDER_NUON_CLI_DOCS_URL) commands in your CI/CD workflows.

## Overview

This action installs the Nuon CLI, configures authentication, and executes arbitrary Nuon commands. It's designed to
integrate Nuon's infrastructure management capabilities directly into your GitHub Actions workflows.

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

| Input          | Description                         | Required | Default               |
| -------------- | ----------------------------------- | -------- | --------------------- |
| `org_id`       | Your Nuon organization ID           | Yes      | -                     |
| `api_token`    | Your Nuon API token                 | Yes      | -                     |
| `app_id`       | The Nuon App ID for the config file   | No       | -                     |
| `api_url`      | The URL of the Nuon API             | No       | `https://api.nuon.co` |
| `nuon_version` | Version of the Nuon CLI to use      | No       | `latest`              |
| `command`      | The Nuon CLI command to execute     | No       | -                     |

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

## Security Best Practices

- **Never commit secrets**: Always use GitHub Secrets for sensitive values like `api_token` and `org_id`
- **Use repository secrets**: Store Nuon credentials in your repository's secrets settings
- **Limit permissions**: Grant the minimum necessary permissions to your Nuon API tokens

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
