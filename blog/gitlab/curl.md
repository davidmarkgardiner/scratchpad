Great question! You can definitely create GitLab issues and associate them with epics. Here are the approaches for each method:

## GitLab CLI (glab) with Epics
```bash
EPIC_ID="123"  # Your epic ID

for file in *.md; do
  # Create the issue first
  issue_url=$(glab issue create --title "$(basename "$file" .md)" --description "$(cat "$file")" --format json | jq -r '.web_url')
  issue_iid=$(echo "$issue_url" | grep -o '[0-9]*$')
  
  # Add to epic (requires GitLab Premium+)
  glab api --method POST "/groups/:group_id/epics/$EPIC_ID/issues" -f issue_id=$issue_iid
done
```

## GitLab API with Epic Association
```bash
#!/bin/bash
PROJECT_ID="your-project-id"
GROUP_ID="your-group-id"
EPIC_ID="your-epic-id"
PRIVATE_TOKEN="your-access-token"
GITLAB_URL="https://gitlab.com"

for file in *.md; do
  title=$(basename "$file" .md)
  description=$(cat "$file" | jq -sRr @json)
  
  # Create the issue
  response=$(curl --silent --request POST \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{\"title\":\"$title\",\"description\":$description}" \
    "$GITLAB_URL/api/v4/projects/$PROJECT_ID/issues")
  
  issue_id=$(echo "$response" | jq -r '.id')
  
  # Add issue to epic (Premium feature)
  curl --request POST \
    --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
    --data "issue_id=$issue_id" \
    "$GITLAB_URL/api/v4/groups/$GROUP_ID/epics/$EPIC_ID/issues"
    
  echo "Created issue $issue_id and added to epic $EPIC_ID"
done
```

## Python script with Epic Support
```python
import gitlab
from pathlib import Path
import time

# Initialize GitLab connection
gl = gitlab.Gitlab('https://gitlab.com', private_token='your-token')
project = gl.projects.get('project-id')
group = gl.groups.get('group-id')  # Epics belong to groups
epic = group.epics.get('epic-id')

# Process markdown files
for md_file in Path('.').glob('*.md'):
    with open(md_file, 'r') as f:
        content = f.read()
    
    # Create issue
    issue = project.issues.create({
        'title': md_file.stem,
        'description': content
    })
    
    # Add to epic (requires Premium+)
    epic_issue = epic.issues.create({
        'issue_id': issue.id
    })
    
    print(f"Created issue {issue.web_url} and added to epic")
    time.sleep(0.5)  # Rate limiting
```

## Enhanced Version with Metadata Parsing
If your Markdown files have frontmatter, you can extract epic information:

```python
import yaml
import gitlab
from pathlib import Path

def parse_markdown_with_frontmatter(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            frontmatter = yaml.safe_load(parts[1])
            body = parts[2].strip()
            return frontmatter, body
    
    return {}, content

# Initialize GitLab
gl = gitlab.Gitlab('https://gitlab.com', private_token='your-token')
project = gl.projects.get('project-id')
group = gl.groups.get('group-id')

for md_file in Path('.').glob('*.md'):
    frontmatter, content = parse_markdown_with_frontmatter(md_file)
    
    # Extract metadata
    title = frontmatter.get('title', md_file.stem)
    epic_id = frontmatter.get('epic_id')
    labels = frontmatter.get('labels', [])
    assignees = frontmatter.get('assignees', [])
    
    # Create issue
    issue_data = {
        'title': title,
        'description': content,
        'labels': labels,
        'assignee_ids': assignees
    }
    
    issue = project.issues.create(issue_data)
    
    # Add to epic if specified
    if epic_id:
        epic = group.epics.get(epic_id)
        epic.issues.create({'issue_id': issue.id})
        print(f"Added issue to epic {epic_id}")
```

## Example Markdown with Frontmatter
```markdown
---
title: "Implement user authentication"
epic_id: 42
labels: ["backend", "security"]
assignees: [123, 456]
---

# User Authentication Implementation

This issue covers implementing OAuth 2.0 authentication...
```

## Important Notes
- **Premium Feature**: Epics require GitLab Premium or higher
- **Group vs Project**: Epics belong to groups, not individual projects
- **Epic IID vs ID**: Make sure you're using the correct identifier
- **Permissions**: You need appropriate permissions to create issues and manage epics

Would you like me to help you set up any specific variation of this workflow?