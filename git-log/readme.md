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