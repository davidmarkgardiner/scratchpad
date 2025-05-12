I'll add those points to the list:

• We didn't expect so many applications to be redeploying at the same time
• The mutation was taking effect before the copy job had a chance to run
• In hindsight, we should run the copy job first
• This approach will be implemented in preprod and prod environments
• It's definitely an option to run a Skopeo or ORAS job before the deployment takes place, which would help with our solution
• We would need to assign the correct ACR push permissions via RBAC and run automation to achieve this

Do these bullet points capture everything you wanted to include?