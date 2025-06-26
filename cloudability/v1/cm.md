```

CLIENT_ID=$(az identity show --name <identity-name> --resource-group <rg-name> --query clientId -o tsv)

# Update ConfigMap
cat > config/configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: azure-identity-config
  namespace: azure-system
data:
  client-id: "${CLIENT_ID}"
  tenant-id: "$(az account show --query tenantId -o tsv)"
EOF

```