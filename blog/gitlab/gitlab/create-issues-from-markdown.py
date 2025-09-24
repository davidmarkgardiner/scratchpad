#!/usr/bin/env python3
"""
GitLab Issue Creator from Markdown
Creates GitLab issues from a structured markdown file using the GitLab CLI (glab).

Usage: python3 create-issues-from-markdown.py [markdown_file]
"""

import re
import sys
import subprocess
import json
from pathlib import Path

def run_glab_command(cmd_args, description=""):
    """Run a glab command and return the result."""
    try:
        print(f"Running: glab {' '.join(cmd_args)}")
        result = subprocess.run(['glab'] + cmd_args,
                              capture_output=True,
                              text=True,
                              check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {e}")
        print(f"stderr: {e.stderr}")
        return None

def parse_markdown_issues(file_path):
    """Parse the markdown file and extract issue information."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []
    current_project = {}

    # Split content by issues (### Issue pattern)
    issue_sections = re.split(r'^### Issue \d+:', content, flags=re.MULTILINE)[1:]

    for section in issue_sections:
        issue = {}

        # Find project context before this issue
        project_match = re.search(r'## Project: (.+?)\n\*\*Milestone:\*\* (.+?)\n\*\*Labels:\*\* (.+?)(?:\n|$)', content)
        if project_match:
            current_project = {
                'name': project_match.group(1),
                'milestone': project_match.group(2),
                'project_labels': project_match.group(3)
            }

        # Extract title (first line after issue header)
        title_match = re.search(r'^(.+?)$', section, re.MULTILINE)
        if title_match:
            issue['title'] = title_match.group(1).strip()

        # Extract description
        desc_match = re.search(r'\*\*Description:\*\*\n(.*?)(?=\*\*[A-Z]|\n---|\Z)', section, re.DOTALL)
        if desc_match:
            issue['description'] = desc_match.group(1).strip()

        # Extract assignee
        assignee_match = re.search(r'\*\*Assignee:\*\* (.+?)(?:\n|$)', section)
        if assignee_match:
            issue['assignee'] = assignee_match.group(1).strip()

        # Extract labels
        labels_match = re.search(r'\*\*Labels:\*\* (.+?)(?:\n|$)', section)
        labels = []
        if labels_match:
            labels.extend(labels_match.group(1).split(','))
        if current_project.get('project_labels'):
            labels.extend(current_project['project_labels'].split(','))
        issue['labels'] = [label.strip() for label in labels if label.strip()]

        # Extract weight
        weight_match = re.search(r'\*\*Weight:\*\* (\d+)', section)
        if weight_match:
            issue['weight'] = int(weight_match.group(1))

        # Extract time estimate
        time_match = re.search(r'\*\*Time Estimate:\*\* (.+?)(?:\n|$)', section)
        if time_match:
            issue['time_estimate'] = time_match.group(1).strip()

        # Add project context
        issue['project'] = current_project.get('name', '')
        issue['milestone'] = current_project.get('milestone', '')

        if issue.get('title'):
            issues.append(issue)

    return issues

def create_milestone_if_not_exists(milestone_name):
    """Create a milestone if it doesn't exist."""
    if not milestone_name:
        return

    print(f"Checking if milestone '{milestone_name}' exists...")

    # List existing milestones
    result = run_glab_command(['api', 'projects/:id/milestones'])
    if result:
        try:
            milestones = json.loads(result)
            existing_milestone = next((m for m in milestones if m['title'] == milestone_name), None)
            if existing_milestone:
                print(f"Milestone '{milestone_name}' already exists")
                return
        except json.JSONDecodeError:
            print("Could not parse milestones response")

    # Create milestone
    print(f"Creating milestone '{milestone_name}'...")
    run_glab_command([
        'api', 'projects/:id/milestones',
        '--method', 'POST',
        '--field', f'title={milestone_name}',
        '--field', f'description=Milestone for {milestone_name} features'
    ])

def create_issue(issue_data):
    """Create a GitLab issue using the glab CLI."""
    cmd_args = ['issue', 'create']

    # Required fields
    cmd_args.extend(['-t', issue_data['title']])
    if issue_data.get('description'):
        cmd_args.extend(['-d', issue_data['description']])

    # Optional fields
    if issue_data.get('labels'):
        cmd_args.extend(['--label', ','.join(issue_data['labels'])])

    if issue_data.get('assignee'):
        cmd_args.extend(['-a', issue_data['assignee']])

    if issue_data.get('milestone'):
        cmd_args.extend(['-m', issue_data['milestone']])

    if issue_data.get('weight'):
        cmd_args.extend(['--weight', str(issue_data['weight'])])

    if issue_data.get('time_estimate'):
        cmd_args.extend(['-e', issue_data['time_estimate']])

    # Skip confirmation
    cmd_args.append('-y')

    return run_glab_command(cmd_args)

def main():
    """Main function to process markdown file and create issues."""
    # Default file path
    markdown_file = 'gitlab/issues-to-create.md'

    # Use command line argument if provided
    if len(sys.argv) > 1:
        markdown_file = sys.argv[1]

    # Check if file exists
    if not Path(markdown_file).exists():
        print(f"Error: File '{markdown_file}' not found")
        sys.exit(1)

    print(f"Parsing issues from: {markdown_file}")
    issues = parse_markdown_issues(markdown_file)

    if not issues:
        print("No issues found in markdown file")
        return

    print(f"Found {len(issues)} issues to create:")
    for i, issue in enumerate(issues, 1):
        print(f"{i}. {issue['title']} [{issue.get('project', 'Unknown')}]")

    # Confirm before creating (auto-confirm for demo)
    print(f"\nProceeding to create {len(issues)} issues...")
    # response = input(f"\nCreate these {len(issues)} issues? (y/N): ")
    # if response.lower() != 'y':
    #     print("Aborted.")
    #     return

    # Create milestones first
    milestones_created = set()
    for issue in issues:
        if issue.get('milestone') and issue['milestone'] not in milestones_created:
            create_milestone_if_not_exists(issue['milestone'])
            milestones_created.add(issue['milestone'])

    # Create issues
    created_issues = []
    for issue in issues:
        print(f"\nCreating issue: {issue['title']}")
        result = create_issue(issue)
        if result:
            print(f"✓ Created: {result}")
            created_issues.append(result)
        else:
            print(f"✗ Failed to create: {issue['title']}")

    print(f"\n🎉 Successfully created {len(created_issues)} issues!")
    for url in created_issues:
        print(f"  - {url}")

if __name__ == "__main__":
    main()