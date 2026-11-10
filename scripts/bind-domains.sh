#!/usr/bin/env bash
# One-time: connect www.damiecodes.com and damiecodes.com to the Static Web App.
# Run after the registrar's nameservers point at the Azure DNS zone and `dig NS` shows them.
set -euo pipefail

RG="${RG:-rg-damiecodes-prod}"
APP="${APP:-damiecodes-portfolio}"
DOMAIN="${DOMAIN:-damiecodes.com}"

echo "Nameservers currently answering for $DOMAIN:"
dig +short NS "$DOMAIN" || true
echo

echo "Binding www.$DOMAIN (validated through its CNAME)..."
az staticwebapp hostname set --name "$APP" --resource-group "$RG" --hostname "www.$DOMAIN"

echo "Requesting a TXT validation token for $DOMAIN..."
az staticwebapp hostname set --name "$APP" --resource-group "$RG" \
  --hostname "$DOMAIN" --validation-method dns-txt-token --no-wait

token=""
for _ in $(seq 1 30); do
  token="$(az staticwebapp hostname show --name "$APP" --resource-group "$RG" \
    --hostname "$DOMAIN" --query validationToken --output tsv 2>/dev/null || true)"
  [[ -n "$token" ]] && break
  sleep 10
done

if [[ -z "$token" ]]; then
  echo "No validation token yet. Wait a few minutes and run this script again." >&2
  exit 1
fi

az network dns record-set txt add-record --resource-group "$RG" --zone-name "$DOMAIN" \
  --record-set-name "@" --value "$token" --output none

cat <<EOF
TXT record added. Validation can take up to an hour. Check progress with:
  az staticwebapp hostname list --name $APP --resource-group $RG --output table

When $DOMAIN shows Ready, open the Static Web App in the Azure portal,
go to Custom domains and choose "Set default" on $DOMAIN so www redirects to it.
EOF
