Here's the configuration formatted in markdown:

```yaml
parameters:
  - name: environment
    type: string
    values:
      - dev
      - test
      - preprod
      - prod
  - name: location
    type: string
    values:
      - northswitzerland
      - southeastasia

variables:
  # Green Zone (3 service connections)
  ${{ if or(eq(parameters.environment, 'dev'), eq(parameters.environment, 'test')) }}:
    serviceConnectionName: 'green-zone-devtest-connection'
  ${{ elseif and(eq(parameters.environment, 'preprod'), not(or(eq(parameters.location, 'northswitzerland'), eq(parameters.location, 'southeastasia')))) }}:
    serviceConnectionName: 'green-zone-preprod-connection'
  ${{ elseif and(eq(parameters.environment, 'prod'), not(or(eq(parameters.location, 'northswitzerland'), eq(parameters.location, 'southeastasia')))) }}:
    serviceConnectionName: 'green-zone-prod-connection'
  
  # Red Zone - North Switzerland (2 service connections)
  ${{ if and(eq(parameters.environment, 'preprod'), eq(parameters.location, 'northswitzerland')) }}:
    serviceConnectionName: 'red-zone-preprod-connection'
  ${{ elseif and(eq(parameters.environment, 'prod'), eq(parameters.location, 'northswitzerland')) }}:
    serviceConnectionName: 'red-zone-prod-connection'
  
  # Singapore Zone - Southeast Asia (2 service connections)
  ${{ if and(eq(parameters.environment, 'preprod'), eq(parameters.location, 'southeastasia')) }}:
    serviceConnectionName: 'singapore-zone-preprod-connection'
  ${{ elseif and(eq(parameters.environment, 'prod'), eq(parameters.location, 'southeastasia')) }}:
    serviceConnectionName: 'singapore-zone-prod-connection'

steps:
- task: AzureCLI@2
  displayName: 'Setup Alert Helper Function'
  inputs:
    azureSubscription: ${{ variables.serviceConnectionName }}
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Your script content here
```

Service Connection Breakdown:

Green Zone (3):
1. green-zone-devtest-connection (dev/test environments)
2. green-zone-preprod-connection (preprod)
3. green-zone-prod-connection (prod)

Red Zone - North Switzerland (2):
4. red-zone-preprod-connection (preprod)
5. red-zone-prod-connection (prod)

Singapore Zone - Southeast Asia (2):
6. singapore-zone-preprod-connection (preprod)
7. singapore-zone-prod-connection (prod)
