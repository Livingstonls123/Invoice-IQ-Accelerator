# GitHub Actions setup (OIDC, no stored Azure credentials)

`ci.yml` runs unit tests and Bicep lint on every PR. `deploy.yml` provisions infra and deploys the MCP server on push to `main` (paths `src/**`, `infra/**`) or manually.

## 1. Create an Entra app with federated credentials
```bash
APP_ID=$(az ad app create --display-name gh-invoiceiq-deploy --query appId -o tsv)
az ad sp create --id $APP_ID
SUB=$(az account show --query id -o tsv)

# Owner is needed because the template creates role assignments.
# Tighter alternative: Contributor + Role Based Access Control Administrator (constrained to the 3 data roles).
az role assignment create --assignee $APP_ID --role Owner --scope /subscriptions/$SUB

az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "gh-env-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:environment:dev",
  "audiences": ["api://AzureADTokenExchange"]
}'
```
Repeat the federated credential for `environment:prod`.

## 2. GitHub repository → Settings → Environments → `dev` (and `prod`)
**Variables**
| Name | Example |
|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | `$SUB` |
| `AZURE_ENV_NAME` | `invoiceiq-dev` |
| `AZURE_LOCATION` | `centralindia` |
| `DOCINTEL_LOCATION` | *(optional)* |

**Secrets**
| Name | Value |
|---|---|
| `MCP_API_KEY` | `openssl rand -hex 32` |

For `prod`, add **required reviewers** so deployments need approval.

## 3. Run
Actions → **Deploy** → *Run workflow* → `dev`. The last step prints the MCP endpoint after a health check.
