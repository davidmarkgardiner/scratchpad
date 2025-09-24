bash# Install glab if you haven't already
# Then authenticate with your GitLab instance

# Create issues from markdown files
for file in *.md; do
  glab issue create --title "$(basename "$file" .md)" --description "$(cat "$file")"
done

EPIC_ID="123"  # Your epic ID

for file in *.md; do
  # Create the issue first
  issue_url=$(glab issue create --title "$(basename "$file" .md)" --description "$(cat "$file")" --format json | jq -r '.web_url')
  issue_iid=$(echo "$issue_url" | grep -o '[0-9]*$')
  
  # Add to epic (requires GitLab Premium+)
  glab api --method POST "/groups/:group_id/epics/$EPIC_ID/issues" -f issue_id=$issue_iid
done