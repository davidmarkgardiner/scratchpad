Our external DNS setup currently injects domain names into private DNS zones in Azure using an operator when virtual services are created. However, we're experiencing an issue where users can hijack or take over domain names that are already in use when this process is run through.

## Proposed Solution

Implement a Kyverno policy that leverages external data sources ([Kyverno External Data Sources](https://kyverno.io/docs/writing-policies/external-data-sources/)) to:

1. Check if the requested domain name is already taken/in use via API lookup 
2. Verify if the domain is already in use on the cluster
3. Reject the virtual service request if the domain is already taken

## Technical Requirements

- Create a Kyverno policy that intercepts virtual service requests
- Configure the policy to make API calls to check domain status
- Implement verification logic to ensure domain uniqueness
- Return appropriate rejection messages when domains are already in use

## Expected Outcome

- Prevent domain name hijacking
- Ensure domain names can only be used by legitimate owners
- Provide clear feedback when domain requests are rejected

## Additional Notes

- We need to determine the best API endpoint to use for domain verification
- Consider rate limiting for external API calls
- Ensure the policy doesn't significantly impact performance of virtual service creation
