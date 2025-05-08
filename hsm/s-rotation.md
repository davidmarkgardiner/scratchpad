# Secret Rotation Strategy with Azure Key Vault and Workload Identity

## Overview

When using Azure Key Vault with Workload Identity, there are two approaches to handling secret rotation:

1. **Application-managed refresh** - The application code actively checks for updated secrets
2. **Kubernetes-triggered restart** - Pods are restarted when secrets change

Each approach has different tradeoffs in terms of complexity, reliability, and operational overhead.

## Option 1: Application-managed Secret Refresh

### How It Works

With this approach, your application code handles secret refresh without requiring pod restarts:

1. The application retrieves the secret from Key Vault on startup
2. The application periodically checks for updated secret values (e.g., every 5 minutes)
3. When a new secret version is detected, the application refreshes its in-memory copy
4. The application uses the latest version of the secret for new operations

### Implementation Example

```csharp
// C# example with secret refresh
public class KeyVaultSecretManager
{
    private readonly SecretClient _secretClient;
    private readonly Dictionary<string, SecretWithMetadata> _secretCache = new();
    private readonly TimeSpan _refreshInterval = TimeSpan.FromMinutes(5);
    private readonly Timer _refreshTimer;
    
    public KeyVaultSecretManager(string keyVaultUrl)
    {
        var credential = new DefaultAzureCredential();
        _secretClient = new SecretClient(new Uri(keyVaultUrl), credential);
        
        // Setup timer to refresh secrets
        _refreshTimer = new Timer(RefreshSecrets, null, TimeSpan.Zero, _refreshInterval);
    }
    
    public async Task<string> GetSecret(string secretName)
    {
        // First check if secret exists in cache and is current
        if (_secretCache.TryGetValue(secretName, out var cachedSecret))
        {
            return cachedSecret.Value;
        }
        
        // If not in cache or expired, get from Key Vault
        return await FetchAndCacheSecret(secretName);
    }
    
    private async void RefreshSecrets(object state)
    {
        try 
        {
            foreach (var secretName in _secretCache.Keys.ToList())
            {
                await FetchAndCacheSecret(secretName);
            }
            Console.WriteLine($"Secret refresh completed at {DateTime.UtcNow}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error refreshing secrets: {ex.Message}");
        }
    }
    
    private async Task<string> FetchAndCacheSecret(string secretName)
    {
        try
        {
            KeyVaultSecret secret = await _secretClient.GetSecretAsync(secretName);
            
            if (_secretCache.TryGetValue(secretName, out var cachedSecret))
            {
                // Only update if the version changed
                if (cachedSecret.Version != secret.Properties.Version)
                {
                    Console.WriteLine($"Updated secret {secretName} from version {cachedSecret.Version} to {secret.Properties.Version}");
                    _secretCache[secretName] = new SecretWithMetadata(secret.Value, secret.Properties.Version);
                }
            }
            else
            {
                // First time fetching this secret
                _secretCache[secretName] = new SecretWithMetadata(secret.Value, secret.Properties.Version);
                Console.WriteLine($"Cached new secret {secretName} with version {secret.Properties.Version}");
            }
            
            return secret.Value;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error fetching secret {secretName}: {ex.Message}");
            
            // Return cached value if we have it, otherwise rethrow
            if (_secretCache.TryGetValue(secretName, out var cachedSecret))
            {
                return cachedSecret.Value;
            }
            
            throw;
        }
    }
    
    private class SecretWithMetadata
    {
        public string Value { get; }
        public string Version { get; }
        
        public SecretWithMetadata(string value, string version)
        {
            Value = value;
            Version = version;
        }
    }
}
```

### Advantages

- **No downtime during rotation** - Application continues running while updating secrets
- **Gradual rollout** - Different pods may update at slightly different times, reducing impact
- **Fault tolerance** - If Key Vault is temporarily unavailable, app can continue using cached secrets
- **Better visibility** - Application can log when secrets are refreshed

### Disadvantages

- **Increased complexity** - Requires implementing cache management and refresh logic
- **Memory usage** - Secrets are kept in memory (and potentially old versions temporarily)
- **Language-specific implementation** - Needs to be implemented in each application language

## Option 2: Kubernetes-triggered Pod Restart

### How It Works

With this approach, pods are restarted when secrets are rotated:

1. An external process monitors Key Vault for secret changes
2. When a secret changes, this process triggers a rolling restart of affected deployments
3. New pods start with the latest secrets from Key Vault

### Implementation Example

Create an Azure Function or Kubernetes CronJob that:

```bash
#!/bin/bash
# This script could run as a Kubernetes CronJob

# Set variables
KEY_VAULT_NAME="your-central-keyvault"
SECRET_NAME="your-application-secret"
NAMESPACE="default"
DEPLOYMENT_NAME="your-application"

# Get the current secret version
CURRENT_VERSION=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name $SECRET_NAME --query "properties.version" -o tsv)

# Check if we have stored the last checked version
if [ -f "/last-secret-version.txt" ]; then
    LAST_CHECKED_VERSION=$(cat /last-secret-version.txt)
else
    LAST_CHECKED_VERSION=""
fi

# If the version has changed, trigger a restart
if [ "$CURRENT_VERSION" != "$LAST_CHECKED_VERSION" ]; then
    echo "Secret version changed from $LAST_CHECKED_VERSION to $CURRENT_VERSION"
    
    # Restart the deployment (rolling update)
    kubectl rollout restart deployment/$DEPLOYMENT_NAME -n $NAMESPACE
    
    # Store the new version
    echo $CURRENT_VERSION > /last-secret-version.txt
    
    echo "Triggered rolling restart of deployment $DEPLOYMENT_NAME"
else
    echo "No changes to secret $SECRET_NAME detected"
fi
```

Or alternatively, use Azure Event Grid to trigger pipeline:

1. Configure Event Grid subscription for Key Vault events
2. When a secret is updated, Event Grid triggers an Azure DevOps pipeline
3. The pipeline identifies and restarts affected deployments

### Advantages

- **Simplicity** - No changes needed to application code
- **Clean state** - Each pod starts fresh with the latest secrets
- **Memory safety** - Old secret values are completely removed when pods restart
- **Central control** - Secret rotation is managed from a single location

### Disadvantages

- **Temporary downtime** - During rolling restarts, some capacity is temporarily unavailable
- **Restart overhead** - Application startup time impacts how quickly rotation completes
- **Additional infrastructure** - Requires setting up monitoring and automation

## Recommended Approach

For most scenarios, the **Application-managed Secret Refresh** approach (Option 1) is recommended:

1. It avoids unnecessary restarts
2. It provides better availability during secret rotation
3. It gives more control over how secrets are refreshed
4. It can be more resilient to temporary Key Vault availability issues

For simple applications or where code changes are difficult, the **Kubernetes-triggered Pod Restart** approach (Option 2) is a viable alternative.

## Implementation Recommendations

1. **Application Code Updates**:
   - Implement secret caching with periodic refresh
   - Add logging for secret version changes
   - Include error handling for Key Vault connectivity issues

2. **Operational Considerations**:
   - Set appropriate refresh intervals (balance freshness vs. API calls)
   - Include monitoring for secret refresh failures
   - Implement alerting for secrets nearing expiration

3. **Secret Rotation Best Practices**:
   - Use secret versions rather than changing the same version
   - Gradually roll out secret changes across environments
   - Implement a grace period where both old and new secrets work
   - Schedule rotations during low-traffic periods