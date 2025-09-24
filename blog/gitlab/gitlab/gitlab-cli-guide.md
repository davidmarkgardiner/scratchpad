# GitLab CLI (glab) Guide: Creating Issues and Working with Epics

## Overview

This guide covers how to use the GitLab CLI (`glab`) to create issues and work with epics. The GitLab CLI is already installed and authenticated on this system.

## Current Authentication Status

```bash
glab auth status
```

You are currently logged in as `davidmarkgardiner` to `gitlab.com`.

## Creating Issues

### Basic Issue Creation

```bash
# Create a basic issue with title and description
glab issue create -t "Issue Title" -d "Issue description here"

# Create issue with interactive editor (default behavior)
glab issue create
```

### Issue Creation with Epic Assignment

The key flag for assigning an issue to an epic is `--epic`:

```bash
# Create an issue and assign it to an epic (replace 123 with epic ID)
glab issue create -t "Feature request" -d "Description" --epic 123
```

### Advanced Issue Creation Examples

```bash
# Create issue with multiple options
glab issue create \
  -t "Fix authentication bug" \
  -d "Users cannot login with SSO" \
  --label "bug,security,high-priority" \
  --assignee "username1,username2" \
  --milestone "v2.1.0" \
  --epic 456 \
  --weight 5 \
  --time-estimate "4h" \
  --due-date "2025-10-01"

# Create confidential issue
glab issue create \
  -t "Security vulnerability" \
  -d "Found XSS in user input" \
  --confidential \
  --label "security" \
  --epic 789

# Create issue and link it to existing issues or MR
glab issue create \
  -t "Documentation update" \
  --linked-issues 100,101 \
  --linked-mr 50 \
  --link-type "blocks"
```

## Issue Creation Flags Reference

| Flag | Description | Example |
|------|-------------|---------|
| `-t, --title` | Issue title | `-t "Bug fix"` |
| `-d, --description` | Issue description | `-d "Detailed description"` |
| `--epic` | ID of epic to assign issue to | `--epic 123` |
| `-l, --label` | Add labels (comma-separated) | `-l "bug,urgent"` |
| `-a, --assignee` | Assign to users | `-a "user1,user2"` |
| `-m, --milestone` | Assign milestone | `-m "v2.0.0"` |
| `--weight` | Issue weight (≥0) | `--weight 3` |
| `--due-date` | Due date (YYYY-MM-DD) | `--due-date "2025-12-31"` |
| `-e, --time-estimate` | Time estimate | `-e "2h 30m"` |
| `-s, --time-spent` | Time spent | `-s "1h 15m"` |
| `--confidential` | Make issue confidential | `--confidential` |
| `--linked-issues` | Link to other issues | `--linked-issues 100,101` |
| `--linked-mr` | Link to merge request | `--linked-mr 50` |
| `--web` | Continue in web interface | `--web` |
| `-y, --yes` | Skip confirmation | `-y` |

## Working with Epics

### Important Note about Epics

The GitLab CLI (`glab`) does not have direct epic management commands. Epics are typically managed through:

1. **GitLab Web Interface** (recommended for epic creation)
2. **GitLab API** (via `glab api` command)
3. **GitLab GraphQL API**

### Finding Epic IDs

To find epic IDs for use with the `--epic` flag:

1. Go to your GitLab group's Epics page
2. Click on the epic you want
3. The URL will show the epic ID: `https://gitlab.com/groups/yourgroup/-/epics/123`
4. Use `123` as the epic ID

### Creating Epics via API

You can create epics using the GitLab API through `glab api`:

```bash
# Create an epic in a group (replace GROUP_ID with your group ID)
glab api groups/GROUP_ID/epics \
  --method POST \
  --field "title=My Epic Title" \
  --field "description=Epic description here"

# Get list of epics in a group
glab api groups/GROUP_ID/epics

# Get specific epic details
glab api groups/GROUP_ID/epics/EPIC_ID
```

### Adding Issues to Existing Epics via API

```bash
# Add an issue to an epic
glab api groups/GROUP_ID/epics/EPIC_ID/issues/ISSUE_ID \
  --method POST
```

## Workflow Examples

### Complete Workflow: Create Epic and Issues

1. **Create Epic** (via web interface or API):
   ```bash
   glab api groups/YOUR_GROUP_ID/epics \
     --method POST \
     --field "title=Feature: User Authentication" \
     --field "description=Complete user authentication system"
   ```

2. **Create Issues for the Epic**:
   ```bash
   # Issue 1: Login form
   glab issue create \
     -t "Create login form component" \
     -d "Build React component for user login" \
     --epic EPIC_ID \
     --label "frontend,authentication" \
     --weight 3

   # Issue 2: Backend API
   glab issue create \
     -t "Implement authentication API endpoints" \
     -d "Create login/logout/register endpoints" \
     --epic EPIC_ID \
     --label "backend,api,authentication" \
     --weight 5

   # Issue 3: Testing
   glab issue create \
     -t "Add authentication tests" \
     -d "Unit and integration tests for auth system" \
     --epic EPIC_ID \
     --label "testing,authentication" \
     --weight 2
   ```

## Useful Commands

```bash
# List issues
glab issue list

# List issues assigned to you
glab issue list --assignee=@me

# List issues in a specific milestone
glab issue list --milestone="v2.0.0"

# View issue details
glab issue view ISSUE_NUMBER

# Get current repository info (useful for API calls)
glab repo view
```

## Tips and Best Practices

1. **Use consistent labeling**: Create a standardized set of labels for your team
2. **Weight estimation**: Use issue weights for sprint planning
3. **Epic organization**: Group related features/initiatives under epics
4. **Time tracking**: Use time estimates and tracking for better planning
5. **Milestones**: Associate issues with milestones for release planning

## Troubleshooting

### Authentication Issues
```bash
# Check auth status
glab auth status

# Re-authenticate if needed
glab auth login
```

### Finding Group/Project IDs
```bash
# Get current project info
glab repo view

# List groups you have access to
glab api groups --paginate
```

### API Rate Limits
If you hit API rate limits, the CLI will show appropriate error messages. Wait and retry, or use the web interface for bulk operations.

## Resources

- [GitLab CLI Documentation](https://docs.gitlab.com/editor_extensions/gitlab_cli/)
- [GitLab REST API Documentation](https://docs.gitlab.com/api/)
- [GitLab GraphQL API Documentation](https://docs.gitlab.com/api/graphql/)
- [Epics Documentation](https://docs.gitlab.com/user/group/epics/)