Here are updated solutions to automatically pull images from Nexus that were pushed in the last 30 minutes:

## ACR Task with Dynamic Image Discovery

**1. ACR Task that discovers and imports recent images:**
```yaml
# acr-nexus-sync.yaml
version: v1.1.0
steps:
  - id: discover-recent-images
    cmd: |
      # Get images pushed in last 30 minutes from Nexus API
      NEXUS_API="{{.Values.nexusUrl}}/service/rest/v1/search"
      CUTOFF_TIME=$(date -d '30 minutes ago' --iso-8601=seconds)
      
      # Query Nexus for recent images
      curl -u "{{.Values.nexusUser}}:{{.Values.nexusPassword}}" \
        "${NEXUS_API}?repository={{.Values.nexusRepo}}&sort=version&direction=desc" \
        | jq -r --arg cutoff "$CUTOFF_TIME" \
        '.items[] | select(.lastModified > $cutoff) | .name + ":" + .version' \
        > /tmp/recent_images.txt
    
  - id: import-images
    cmd: |
      while IFS= read -r image; do
        if [ ! -z "$image" ]; then
          echo "Importing recent image: $image"
          az acr import \
            --name {{.Values.acrName}} \
            --source {{.Values.nexusRegistry}}/$image \
            --image $image \
            --username {{.Values.nexusUser}} \
            --password {{.Values.nexusPassword}} \
            --force
        fi
      done < /tmp/recent_images.txt
```

**Create and schedule the task:**
```bash
# Create task that runs every 30 minutes
az acr task create \
  --registry myacr \
  --name nexus-sync-30min \
  --context /dev/null \
  --file acr-nexus-sync.yaml \
  --schedule "*/30 * * * *" \
  --set acrName=myacr \
  --set nexusUrl=https://nexus-registry.company.com \
  --set nexusRegistry=nexus-registry.company.com \
  --set nexusRepo=docker-hosted \
  --set nexusUser=sync-user \
  --set nexusPassword=sync-password
```

## PowerShell Script for Windows environments

**2. PowerShell script with Nexus API integration:**
```powershell
# nexus-acr-sync.ps1
param(
    [string]$NexusUrl = "https://nexus-registry.company.com",
    [string]$NexusRepo = "docker-hosted",
    [string]$NexusUser = "sync-user",
    [string]$NexusPassword = "sync-password",
    [string]$ACRName = "myacr"
)

# Calculate cutoff time (30 minutes ago)
$CutoffTime = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

# Get recent images from Nexus
$Headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${NexusUser}:${NexusPassword}"))
}

$SearchUrl = "${NexusUrl}/service/rest/v1/search?repository=${NexusRepo}&sort=lastModified&direction=desc"
$Response = Invoke-RestMethod -Uri $SearchUrl -Headers $Headers

# Filter images by last modified time
$RecentImages = $Response.items | Where-Object { 
    [DateTime]$_.lastModified -gt [DateTime]$CutoffTime 
} | ForEach-Object {
    "$($_.name):$($_.version)"
}

# Import each recent image
foreach ($Image in $RecentImages) {
    Write-Host "Importing recent image: $Image"
    az acr import `
        --name $ACRName `
        --source "${NexusUrl}/${Image}" `
        --image $Image `
        --username $NexusUser `
        --password $NexusPassword `
        --force
}

Write-Host "Imported $($RecentImages.Count) recent images"
```

**Schedule with Task Scheduler:**
```powershell
# Create scheduled task to run every 30 minutes
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\scripts\nexus-acr-sync.ps1"
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName "NexusACRSync" -Action $Action -Trigger $Trigger
```

## Bash Script with Cron

**3. Linux/Bash solution:**
```bash
#!/bin/bash
# nexus-acr-sync.sh

NEXUS_URL="https://nexus-registry.company.com"
NEXUS_REPO="docker-hosted"
NEXUS_USER="sync-user"
NEXUS_PASSWORD="sync-password"
ACR_NAME="myacr"

# Calculate cutoff time (30 minutes ago)
CUTOFF_TIME=$(date -d '30 minutes ago' --iso-8601=seconds)

echo "Looking for images newer than: $CUTOFF_TIME"

# Query Nexus API for recent images
RECENT_IMAGES=$(curl -s -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  "${NEXUS_URL}/service/rest/v1/search?repository=${NEXUS_REPO}&sort=lastModified&direction=desc" \
  | jq -r --arg cutoff "$CUTOFF_TIME" \
  '.items[] | select(.lastModified > $cutoff) | .name + ":" + .version')

# Import each recent image
if [ -z "$RECENT_IMAGES" ]; then
  echo "No new images found in the last 30 minutes"
else
  echo "Found recent images:"
  echo "$RECENT_IMAGES"
  
  echo "$RECENT_IMAGES" | while IFS= read -r image; do
    if [ ! -z "$image" ]; then
      echo "Importing: $image"
      az acr import \
        --name "$ACR_NAME" \
        --source "${NEXUS_URL}/${image}" \
        --image "$image" \
        --username "$NEXUS_USER" \
        --password "$NEXUS_PASSWORD" \
        --force
    fi
  done
fi
```

**Set up cron job:**
```bash
# Add to crontab (runs every 30 minutes)
*/30 * * * * /path/to/nexus-acr-sync.sh >> /var/log/nexus-sync.log 2>&1
```

## Azure Logic App Solution

**4. Serverless approach with Logic App:**
```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "triggers": {
      "Recurrence": {
        "type": "Recurrence",
        "recurrence": {
          "frequency": "Minute",
          "interval": 30
        }
      }
    },
    "actions": {
      "Query_Nexus_API": {
        "type": "Http",
        "inputs": {
          "method": "GET",
          "uri": "https://nexus-registry.company.com/service/rest/v1/search?repository=docker-hosted&sort=lastModified&direction=desc",
          "authentication": {
            "type": "Basic",
            "username": "@parameters('nexusUser')",
            "password": "@parameters('nexusPassword')"
          }
        }
      },
      "Filter_Recent_Images": {
        "type": "Query",
        "inputs": {
          "from": "@body('Query_Nexus_API')['items']",
          "where": "@greater(item()['lastModified'], addMinutes(utcNow(), -30))"
        }
      },
      "Import_Images": {
        "type": "Foreach",
        "foreach": "@body('Filter_Recent_Images')",
        "actions": {
          "Import_to_ACR": {
            "type": "Http",
            "inputs": {
              "method": "POST",
              "uri": "https://management.azure.com/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.ContainerRegistry/registries/{acr}/importImage",
              "body": {
                "source": {
                  "sourceImage": "@{items('Import_Images')['name']}:@{items('Import_Images')['version']}",
                  "registryUri": "nexus-registry.company.com"
                },
                "targetTags": ["@{items('Import_Images')['name']}:@{items('Import_Images')['version']}"]
              }
            }
          }
        }
      }
    }
  }
}
```

## Key Features of These Solutions:

- **Time-based filtering**: Only pulls images from the last 30 minutes
- **Automated discovery**: Uses Nexus API to find recent images
- **Scheduled execution**: Runs every 30 minutes automatically  
- **Error handling**: Continues processing even if some imports fail
- **Logging**: Tracks what was imported and when

Which approach works best for your environment? The ACR Task approach is probably the most Azure-native, while the bash/PowerShell scripts offer more flexibility for complex logic.