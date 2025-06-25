Here are several ways to find out who deleted the `kyvernotests` folder from your Git repository:

## 1. Search Git Log for the Folder
```bash
git log --oneline --name-status -- kyvernotests/
```
This shows all commits that touched the folder, including the deletion.

## 2. Find Deletions with `--diff-filter`
```bash
git log --diff-filter=D --summary -- kyvernotests/
```
This specifically looks for deletions (`D`) and shows a summary.

## 3. Use `git log --follow` with Pickaxe
```bash
git log -p --all -- kyvernotests/
```
Shows the full diff of all changes to that path across all branches.

## 4. Search for the Deletion Commit
```bash
git log --oneline | xargs -I {} git diff-tree --no-commit-id --name-status {} | grep -B1 "D.*kyvernotests"
```

## 5. More Targeted Search
```bash
git log --all --full-history -- kyvernotests/
```
Searches all branches and shows the complete history.

## 6. Find When Files Disappeared
```bash
git log --stat --all | grep -B5 -A5 kyvernotests
```

## 7. Use Git's Revision Walking
```bash
git rev-list --all | xargs git grep -l "kyvernotests" | head -1 | xargs git log --oneline
```

## 8. Check Specific Commit Details
Once you find the commit hash, get full details:
```bash
git show <commit-hash>
```

The most reliable approach is usually the first command (`git log --oneline --name-status -- kyvernotests/`), which will show you:
- The commit hash
- The author
- The date
- Whether files were added (A), modified (M), or deleted (D)

If the folder was renamed rather than deleted, add `--follow`:
```bash
git log --oneline --name-status --follow -- kyvernotests/
```


---

Let me help you with more specific commands to track down the deletion:

## 1. Check if the folder still exists in recent history
```bash
git log --all --full-history --oneline -- "*kyvernotests*"
```

## 2. Find the last commit where the folder existed
```bash
git log --all --oneline -- kyvernotests/ | head -5
```

## 3. Search for commits that mention the folder name
```bash
git log --all --grep="kyvernotests" --oneline
git log --all --grep="kyverno" --oneline
```

## 4. Look for large deletions in recent commits
```bash
git log --oneline --stat | grep -B2 -A2 "deletion"
```

## 5. Check what happened between commits
If you find the last commit where it existed, compare with the next one:
```bash
# First, find when it last existed
git log --all --oneline -- kyvernotests/ | head -1

# Then check what happened in the next few commits
git log --oneline -10
```

## 6. More aggressive search for any mention
```bash
git log --all -S "kyvernotests" --oneline
git log --all -G "kyvernotests" --oneline
```

## 7. Check if it was moved/renamed instead of deleted
```bash
git log --all --follow --stat -- "*kyverno*"
```

## 8. Look at directory-level changes
```bash
git log --name-only --oneline | grep -B1 -A5 kyvernotests
```

Try these in order. If the folder name appears in any output, that commit likely contains the deletion. Then use:
```bash
git show <commit-hash> --name-status
```

**Quick question**: Are you sure the folder was called exactly `kyvernotests`? Could it have been `kyverno-tests`, `kyverno_tests`, or similar? You might want to try:
```bash
git log --all --oneline -- "*kyverno*"
```