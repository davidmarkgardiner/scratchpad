In Azure Container Registry, you can also set policies to clean up images based on when they were last pulled (accessed). This is particularly useful for identifying and removing unused images.

Here's how to do it:

```bash
# Delete images not pulled in last 90 days
az acr run --cmd "acr purge --filter 'your-repo:.*' --last-pull-older-than 90d" \
    --registry yourregistry \
    /dev/null
```

You can combine multiple conditions:
```bash
# Delete images not pulled in 90 days AND older than 30 days
az acr run --cmd "acr purge --filter 'your-repo:.*' --last-pull-older-than 90d --ago 30d" \
    --registry yourregistry \
    /dev/null
```

Best practices:
1. Always run with `--dry-run` first to see what would be deleted
2. Use `--keep` flag to retain N most recent tags
3. Schedule during off-peak hours
4. Consider setting up monitoring/alerts for space usage

Would you like me to show you how to check which images haven't been pulled recently before setting up the purge policy?

---

Yes, Azure Container Registry supports automated cleanup of old images through what's called "lifecycle management policies". Let me help you set this up:

1. You can create purge rules using the `az acr run-task create` command, which can:
- Delete images by age
- Keep a certain number of recent tags
- Target specific repositories
- Delete untagged (dangling) images

Here's a practical example:

```bash
# Create a task to purge images older than 30 days, but keep at least 3 most recent tags
az acr task create \
    --name cleanup-task \
    --registry yourregistry \
    --cmd "acr purge --filter 'your-repo:.*' --ago 30d --keep 3" \
    --schedule "0 0 * * *"  # Runs daily at midnight
```

2. For untagged manifests (which often consume a lot of space), you can run:
```bash
az acr run --cmd "acr purge --filter 'your-repo:.*' --untagged" \
    --registry yourregistry \
    /dev/null
```

3. To check what would be deleted before actually running the purge:
```bash
# Dry run mode
az acr run --cmd "acr purge --filter 'your-repo:.*' --ago 30d --dry-run" \
    --registry yourregistry \
    /dev/null
```

Important Considerations:
- Run purge operations during off-peak hours
- Always test with --dry-run first
- Consider keeping important release tags using a specific tag pattern
- Be careful with wildcards in repository filters

Would you like me to help you craft a specific cleanup policy for your use case?
