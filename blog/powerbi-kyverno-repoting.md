Here's how to connect Power BI to Kubernetes API and pull Kyverno policy reports:

## 1. Kubernetes API Connection Setup

**Power BI Web Connector Configuration:**
```
URL: https://your-k8s-api-server/api/v1/namespaces
Authentication: Custom Headers
Authorization: Bearer <your-service-account-token>
```

## 2. Kyverno Policy Reports API Endpoints

Kyverno creates custom resources that you can query:

**Cluster Policy Reports:**
```
GET https://your-k8s-api-server/apis/wgpolicyk8s.io/v1alpha2/clusterpolicyreports
```

**Namespace Policy Reports:**
```
GET https://your-k8s-api-server/apis/wgpolicyk8s.io/v1alpha2/namespaces/{namespace}/policyreports
```

## 3. Power BI M Query Example

Here's the Power Query M code to fetch Kyverno reports:

```m
let
    // API Configuration
    ApiUrl = "https://your-k8s-cluster/apis/wgpolicyk8s.io/v1alpha2/clusterpolicyreports",
    Token = "your-service-account-token",
    
    // Headers
    Headers = [
        #"Authorization" = "Bearer " & Token,
        #"Content-Type" = "application/json"
    ],
    
    // API Call
    Source = Json.Document(Web.Contents(ApiUrl, [Headers=Headers])),
    
    // Extract items array
    Items = Source[items],
    
    // Convert to table
    ItemsTable = Table.FromList(Items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    
    // Expand the Column1 to get report details
    ExpandedReports = Table.ExpandRecordColumn(ItemsTable, "Column1", 
        {"metadata", "spec", "status", "results"}, 
        {"metadata", "spec", "status", "results"}),
    
    // Expand metadata for report names and namespaces
    ExpandedMetadata = Table.ExpandRecordColumn(ExpandedReports, "metadata", 
        {"name", "namespace", "creationTimestamp"}, 
        {"ReportName", "Namespace", "CreatedAt"}),
    
    // Expand results to get individual policy violations
    ExpandedResults = Table.ExpandListColumn(ExpandedMetadata, "results"),
    ResultsTable = Table.ExpandRecordColumn(ExpandedResults, "results", 
        {"policy", "rule", "result", "severity", "message", "source"}, 
        {"Policy", "Rule", "Result", "Severity", "Message", "Source"})
        
in
    ResultsTable
```

## 4. Service Account Setup

Create a service account with appropriate permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: powerbi-reader
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: powerbi-kyverno-reader
rules:
- apiGroups: ["wgpolicyk8s.io"]
  resources: ["policyreports", "clusterpolicyreports"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: powerbi-kyverno-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: powerbi-kyverno-reader
subjects:
- kind: ServiceAccount
  name: powerbi-reader
  namespace: default
```

## 5. Get Service Account Token

```bash
# Get the token
kubectl get secret $(kubectl get serviceaccount powerbi-reader -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode
```

## 6. Sample Power BI Dashboard Metrics

Once connected, you can create reports showing:

- **Policy Violation Summary by Severity**
- **Top Violating Policies**
- **Compliance Trends Over Time**
- **Namespace Compliance Scores**
- **Resource Types with Most Violations**

## 7. Specific Kyverno Report Queries

**Get Failed Policy Violations:**
```m
FilteredResults = Table.SelectRows(ResultsTable, each [Result] = "fail")
```

**Group by Policy Name:**
```m
GroupedByPolicy = Table.Group(ResultsTable, {"Policy"}, {
    {"ViolationCount", each Table.RowCount(_), Int64.Type},
    {"FailedCount", each Table.RowCount(Table.SelectRows(_, each [Result] = "fail")), Int64.Type}
})
```

## 8. Refresh Configuration

Set up automatic refresh in Power BI Service:
- Configure scheduled refresh
- Store credentials securely
- Set refresh frequency (hourly/daily based on needs)

This approach gives you real-time visibility into Kyverno policy compliance without requiring additional cluster policies or complex setups.