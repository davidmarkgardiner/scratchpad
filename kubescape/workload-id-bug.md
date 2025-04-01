It looks like your GitLab pipeline script is failing when trying to create federated credentials for managed identities. The error message "Issuer and subject combination already exists for this Managed Identity" indicates that the credential you're trying to create already exists.

Here's how to fix this issue:

1. First, check if the credential already exists before trying to create it:

```bash
# For the vault federated credential
az identity federated-credential show --name federated_workload_identity_vault${trimmed_clusterprefix} \
    --identity-name ${UAMI} \
    --resource-group ${UAMI_RESOURCE_GROUP} > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "[INFO] Federated credential for vault already exists. Skipping creation."
else
    # Create the federated credential for vault
    az identity federated-credential create --name federated_workload_identity_vault${trimmed_clusterprefix} \
        --identity-name ${UAMI} \
        --resource-group ${UAMI_RESOURCE_GROUP} \
        --issuer "${AKS_OIDC_ISSUER}" \
        --subject system:serviceaccount:"ubs-system":"vault-sa"
    
    [ $? -eq 0 ] && echo "[SUCCESS] Federated Credentials created for federated_workload_identity_vault." || { echo "[ERROR] Failed to create federated credentials for federated_workload_identity_vault."; exit 1; }
fi

# For the imageswap federated credential
az identity federated-credential show --name federated_workload_identity_imageswap${trimmed_clusterprefix} \
    --identity-name ${RUNTIME_MANAGEDIDENTITY} \
    --resource-group ${UAMI_RESOURCE_GROUP} > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "[INFO] Federated credential for imageswap already exists. Skipping creation."
else
    # Create the federated credential for imageswap
    az identity federated-credential create --name federated_workload_identity_imageswap${trimmed_clusterprefix} \
        --identity-name ${RUNTIME_MANAGEDIDENTITY} \
        --resource-group ${UAMI_RESOURCE_GROUP} \
        --issuer "${AKS_OIDC_ISSUER}" \
        --subject system:serviceaccount:"kyverno":"acrpush-workload-identity-sa"
    
    [ $? -eq 0 ] && echo "[SUCCESS] Federated Credentials created for federated_workload_identity_imageswap." || { echo "[ERROR] Failed to create federated credentials for federated_workload_identity_imageswap."; exit 1; }
fi
```

This approach checks if the federated credentials already exist before attempting to create them. If they exist, it skips the creation step, preventing the error.

Alternatively, if you prefer a simpler approach, you can update the existing federated credentials instead of creating new ones:

```bash
# Update the existing federated credential for vault
az identity federated-credential update --name federated_workload_identity_vault${trimmed_clusterprefix} \
    --identity-name ${UAMI} \
    --resource-group ${UAMI_RESOURCE_GROUP} \
    --issuer "${AKS_OIDC_ISSUER}" \
    --subject system:serviceaccount:"ubs-system":"vault-sa"

# Update the existing federated credential for imageswap
az identity federated-credential update --name federated_workload_identity_imageswap${trimmed_clusterprefix} \
    --identity-name ${RUNTIME_MANAGEDIDENTITY} \
    --resource-group ${UAMI_RESOURCE_GROUP} \
    --issuer "${AKS_OIDC_ISSUER}" \
    --subject system:serviceaccount:"kyverno":"acrpush-workload-identity-sa"
```

Either of these approaches should resolve the conflict error in your pipeline.