# infra

Bicep for everything damiecodes.com runs on in Azure. Today that is the portfolio's Static Web App (Free) and the `damiecodes.com` DNS zone. Side projects add modules here as they ship.

GitHub Actions deploys this repo with OpenID Connect, so no Azure secret is stored in GitHub. Pull requests run a what-if and post it to the job summary; merges to `main` deploy.

## One-time setup

Use your **personal** Azure subscription and GitHub account for every step, not your work tenant.

### 1. Tools and sign-in

```bash
brew install azure-cli gh
```

```bash
az login
```

```bash
az account show --query "{subscription:name, tenant:tenantId}" --output table
```

If the subscription shown is a work one, switch with `az account set --subscription <name-or-id>`.

### 2. First deployment from your machine

```bash
az group create --name rg-damiecodes-prod --location westeurope
```

```bash
az deployment group create --resource-group rg-damiecodes-prod --template-file main.bicep --query properties.outputs
```

The output lists four Azure nameservers.

### 3. Point the domain at Azure DNS

**Before you change anything at your registrar**, copy any records that already exist there (especially `MX` and `TXT` records for email) into the new Azure zone. Changing nameservers replaces all DNS for the domain, so email stops working if those records aren't copied first.

Then replace the nameservers at your registrar with the four from step 2. Propagation usually takes minutes but can take up to 48 hours. Check with:

```bash
dig +short NS damiecodes.com
```

### 4. Let GitHub Actions deploy without secrets (OIDC)

Replace `<github-user>` with your personal GitHub username.

```bash
APP_ID=$(az ad app create --display-name gh-damiecodes-infra --query appId --output tsv)
az ad sp create --id "$APP_ID" --output none
SUB_ID=$(az account show --query id --output tsv)
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/rg-damiecodes-prod" --output none
for ENV in plan production; do
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"github-infra-$ENV\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:<github-user>/infra:environment:$ENV\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done
gh variable set AZURE_CLIENT_ID --repo <github-user>/infra --body "$APP_ID"
gh variable set AZURE_TENANT_ID --repo <github-user>/infra --body "$(az account show --query tenantId --output tsv)"
gh variable set AZURE_SUBSCRIPTION_ID --repo <github-user>/infra --body "$SUB_ID"
```

These are identifiers, not secrets, so they live in repository variables.

### 5. Give the portfolio repo its deployment token

```bash
az staticwebapp secrets list --name damiecodes-portfolio --resource-group rg-damiecodes-prod \
  --query properties.apiKey --output tsv | gh secret set SWA_TOKEN --repo <github-user>/portfolio
```

### 6. Connect the domain

Once `dig` shows the Azure nameservers:

```bash
./scripts/bind-domains.sh
```

The script binds `www` through its CNAME and the apex through a TXT validation token, then tells you to set the apex as the default domain so `www` redirects to it.

## Day to day

- Change `main.bicep` on a branch and open a pull request. The **Build and what-if** check shows exactly what would change.
- Merge to deploy.
