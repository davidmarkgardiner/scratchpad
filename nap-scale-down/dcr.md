# Azure Monitor Data Collection Rule Examples
Here are practical examples for the Azure Monitor Data Collection Rule commands:These examples cover the most common scenarios for Azure Monitor Data Collection Rules:

**Basic Operations:**
- Creating simple performance counter and event log collection rules
- Listing and viewing existing rules
- Basic updates and deletions

**Advanced Scenarios:**
- Multi-source data collection (performance counters + event logs + syslog)
- Using JSON configuration files for complex setups
- Custom stream declarations
- Data transformation with KQL
- Integration with Data Collection Endpoints

**Key Tips:**
1. Always specify the correct `--kind` (Linux/Windows) for platform-specific rules
2. Use meaningful names for data sources and destinations
3. Consider sampling frequency impact on costs and performance
4. Test XPath queries for Windows Event Logs before deploying
5. Use resource IDs in the correct format for destinations

The examples include real-world scenarios like web server monitoring, security event collection, and Linux system monitoring that you can adapt to your specific needs.

## 1. Create a Basic Data Collection Rule

### Simple Performance Counter Collection
```bash
az monitor data-collection rule create \
  --resource-group "myResourceGroup" \
  --location "eastus" \
  --name "basic-perf-rule" \
  --data-sources '{
    "performanceCounters": [{
      "name": "basicPerfCounters",
      "streams": ["Microsoft-Perf"],
      "samplingFrequencyInSeconds": 60,
      "counterSpecifiers": [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes"
      ]
    }]
  }' \
  --destinations '{
    "logAnalytics": [{
      "name": "myWorkspace",
      "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myResourceGroup/providers/Microsoft.OperationalInsights/workspaces/myWorkspace"
    }]
  }' \
  --data-flows '[{
    "streams": ["Microsoft-Perf"],
    "destinations": ["myWorkspace"]
  }]'
```

### Windows Event Log Collection
```bash
az monitor data-collection rule create \
  --resource-group "security-rg" \
  --location "westus2" \
  --name "windows-security-events" \
  --data-sources '{
    "windowsEventLogs": [{
      "name": "securityEvents",
      "streams": ["Microsoft-WindowsEvent"],
      "xPathQueries": [
        "Security!*[System[(EventID=4624 or EventID=4625)]]",
        "System!*[System[Level=2]]"
      ]
    }]
  }' \
  --destinations '{
    "logAnalytics": [{
      "name": "securityWorkspace",
      "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/security-rg/providers/Microsoft.OperationalInsights/workspaces/security-workspace"
    }]
  }' \
  --data-flows '[{
    "streams": ["Microsoft-WindowsEvent"],
    "destinations": ["securityWorkspace"]
  }]'
```

## 2. Create Advanced Multi-Source Rule

### Linux Syslog + Performance Counters
```bash
az monitor data-collection rule create \
  --resource-group "prod-monitoring" \
  --location "eastus" \
  --name "linux-comprehensive-monitoring" \
  --kind "Linux" \
  --data-sources '{
    "syslog": [{
      "name": "linuxSyslog",
      "streams": ["Microsoft-Syslog"],
      "facilityNames": ["auth", "cron", "daemon", "kern", "syslog"],
      "logLevels": ["Warning", "Error", "Critical", "Alert", "Emergency"]
    }],
    "performanceCounters": [{
      "name": "linuxPerfCounters",
      "streams": ["Microsoft-Perf"],
      "samplingFrequencyInSeconds": 30,
      "counterSpecifiers": [
        "\\Processor\\PercentProcessorTime",
        "\\Memory\\PercentUsedMemory",
        "\\Logical Disk\\PercentUsedSpace"
      ]
    }]
  }' \
  --destinations '{
    "logAnalytics": [{
      "name": "prodWorkspace",
      "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-monitoring/providers/Microsoft.OperationalInsights/workspaces/prod-workspace"
    }]
  }' \
  --data-flows '[
    {
      "streams": ["Microsoft-Syslog"],
      "destinations": ["prodWorkspace"]
    },
    {
      "streams": ["Microsoft-Perf"],
      "destinations": ["prodWorkspace"]
    }
  ]'
```

## 3. Create Rule with JSON File

### Create JSON configuration file first
```json
{
  "properties": {
    "dataSources": {
      "performanceCounters": [{
        "name": "webServerCounters",
        "streams": ["Microsoft-Perf"],
        "samplingFrequencyInSeconds": 15,
        "counterSpecifiers": [
          "\\Web Service(_Total)\\Current Connections",
          "\\Web Service(_Total)\\Bytes Received/sec",
          "\\Web Service(_Total)\\Bytes Sent/sec"
        ]
      }],
      "windowsEventLogs": [{
        "name": "iisLogs",
        "streams": ["Microsoft-WindowsEvent"],
        "xPathQueries": ["System!*[System[Provider[@Name='Microsoft-Windows-IIS-Logging']]]"]
      }]
    },
    "destinations": {
      "logAnalytics": [{
        "name": "webWorkspace",
        "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/web-rg/providers/Microsoft.OperationalInsights/workspaces/web-workspace"
      }]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Perf", "Microsoft-WindowsEvent"],
        "destinations": ["webWorkspace"]
      }
    ]
  }
}
```

### Use the JSON file
```bash
az monitor data-collection rule create \
  --resource-group "web-rg" \
  --location "centralus" \
  --name "web-server-monitoring" \
  --rule-file "./web-dcr-config.json"
```

## 4. List and Show Operations

### List all DCRs in resource group
```bash
az monitor data-collection rule list --resource-group "myResourceGroup"
```

### List all DCRs in subscription
```bash
az monitor data-collection rule list
```

### Show specific DCR details
```bash
az monitor data-collection rule show \
  --name "basic-perf-rule" \
  --resource-group "myResourceGroup"
```

## 5. Update Existing Rule

### Add new performance counters
```bash
az monitor data-collection rule update \
  --resource-group "myResourceGroup" \
  --name "basic-perf-rule" \
  --performance-counters \
    name="additionalCounters" \
    streams="Microsoft-Perf" \
    sampling-frequency=30 \
    counter-specifiers="\\Process(_Total)\\Thread Count" \
    counter-specifiers="\\System\\Processor Queue Length"
```

### Update data flows
```bash
az monitor data-collection rule update \
  --resource-group "myResourceGroup" \
  --name "basic-perf-rule" \
  --data-flows \
    destinations="myWorkspace" \
    streams="Microsoft-Perf" \
    streams="Microsoft-Syslog"
```

### Add tags
```bash
az monitor data-collection rule update \
  --resource-group "myResourceGroup" \
  --name "basic-perf-rule" \
  --tags "Environment=Production" "Team=Infrastructure" "CostCenter=IT001"
```

## 6. Delete Operations

### Delete specific DCR
```bash
az monitor data-collection rule delete \
  --name "basic-perf-rule" \
  --resource-group "myResourceGroup"
```

### Delete DCR and all associations
```bash
az monitor data-collection rule delete \
  --name "basic-perf-rule" \
  --resource-group "myResourceGroup" \
  --delete-associations true \
  --yes
```

## 7. Advanced Scenarios

### Custom Stream Declaration
```bash
az monitor data-collection rule create \
  --resource-group "custom-monitoring" \
  --location "eastus" \
  --name "custom-stream-rule" \
  --stream-declarations '{
    "Custom-MyApp-Logs": {
      "columns": [
        {"name": "TimeGenerated", "type": "datetime"},
        {"name": "Application", "type": "string"},
        {"name": "Level", "type": "string"},
        {"name": "Message", "type": "string"}
      ]
    }
  }' \
  --destinations '{
    "logAnalytics": [{
      "name": "customWorkspace",
      "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/custom-monitoring/providers/Microsoft.OperationalInsights/workspaces/custom-workspace"
    }]
  }' \
  --data-flows '[{
    "streams": ["Custom-MyApp-Logs"],
    "destinations": ["customWorkspace"],
    "transformKql": "source | where Level != \"Debug\""
  }]'
```

### Using Data Collection Endpoint
```bash
az monitor data-collection rule create \
  --resource-group "endpoint-monitoring" \
  --location "eastus" \
  --name "endpoint-based-rule" \
  --data-collection-endpoint-id "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/endpoint-monitoring/providers/Microsoft.Insights/dataCollectionEndpoints/my-endpoint" \
  --destinations '{
    "logAnalytics": [{
      "name": "endpointWorkspace",
      "workspaceResourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/endpoint-monitoring/providers/Microsoft.OperationalInsights/workspaces/endpoint-workspace"
    }]
  }'
```

## Common Performance Counter Specifiers

### Windows
- `\\Processor(_Total)\\% Processor Time`
- `\\Memory\\Available MBytes`
- `\\PhysicalDisk(_Total)\\Disk Reads/sec`
- `\\PhysicalDisk(_Total)\\Disk Writes/sec`
- `\\Network Interface(*)\\Bytes Total/sec`
- `\\Process(_Total)\\Thread Count`
- `\\System\\Processor Queue Length`

### Linux
- `\\Processor\\PercentProcessorTime`
- `\\Memory\\PercentUsedMemory`
- `\\Logical Disk\\PercentUsedSpace`
- `\\Network\\TotalRxErrors`
- `\\Network\\TotalTxErrors`

## Common XPath Queries for Windows Events

### Security Events
- `Security!*[System[(EventID=4624 or EventID=4625 or EventID=4648)]]` - Logon events
- `Security!*[System[Level=2]]` - Error level security events

### System Events
- `System!*[System[Level=1 or Level=2 or Level=3]]` - Critical, Error, Warning
- `System!*[System[Provider[@Name='Microsoft-Windows-Kernel-General']]]`

### Application Events
- `Application!*[System[Level=2]]` - Application errors
- `Application!*[System[Provider[@Name='Application Error']]]`

```