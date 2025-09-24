#!/usr/bin/env python3
"""
GitLab Bulk Issue Creator from Multiple Markdown Files
Processes all *.md files in a target folder and creates GitLab issues from them.

Usage: python3 process-all-markdown-files.py [target_folder]
"""

import re
import sys
import subprocess
import json
import glob
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
    print(f"  📄 Processing: {file_path}")

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []
    current_project = {}

    # Check if this is an issue definition file
    if not re.search(r'### Issue \d+:', content):
        print(f"  ⏭️  Skipping {file_path}: No issue definitions found")
        return []

    # Split content by issues (### Issue pattern)
    issue_sections = re.split(r'^### Issue \d+:', content, flags=re.MULTILINE)[1:]

    # Find project context (could be anywhere in the file)
    project_matches = re.findall(r'## Project: (.+?)\n\*\*Milestone:\*\* (.+?)\n\*\*Labels:\*\* (.+?)(?:\n|$)', content)

    current_project_index = 0

    for i, section in enumerate(issue_sections):
        issue = {}

        # Determine which project context applies to this issue
        if project_matches:
            # Find the right project context by looking for project headers before this issue
            section_start = content.find(f'### Issue {i+1}:')
            relevant_project = None

            for project_match in project_matches:
                project_header_pattern = f'## Project: {re.escape(project_match[0])}'
                project_pos = content.rfind(project_header_pattern, 0, section_start)
                if project_pos != -1:
                    relevant_project = {
                        'name': project_match[0],
                        'milestone': project_match[1],
                        'project_labels': project_match[2]
                    }

            if relevant_project:
                current_project = relevant_project

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

        # Extract due date
        due_date_match = re.search(r'\*\*Due Date:\*\* (.+?)(?:\n|$)', section)
        if due_date_match:
            issue['due_date'] = due_date_match.group(1).strip()

        # Add project context and source file
        issue['project'] = current_project.get('name', 'Unknown')
        issue['milestone'] = current_project.get('milestone', '')
        issue['source_file'] = str(file_path)

        if issue.get('title'):
            issues.append(issue)

    print(f"  ✅ Found {len(issues)} issues in {file_path}")
    return issues

def create_milestone_if_not_exists(milestone_name):
    """Create a milestone if it doesn't exist."""
    if not milestone_name:
        return

    print(f"  🎯 Checking milestone '{milestone_name}'...")

    # List existing milestones
    result = run_glab_command(['api', 'projects/:id/milestones'])
    if result:
        try:
            milestones = json.loads(result)
            existing_milestone = next((m for m in milestones if m['title'] == milestone_name), None)
            if existing_milestone:
                print(f"  ✅ Milestone '{milestone_name}' exists")
                return
        except json.JSONDecodeError:
            print("  ⚠️  Could not parse milestones response")

    # Create milestone
    print(f"  🆕 Creating milestone '{milestone_name}'...")
    result = run_glab_command([
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
        # Add source file info to description
        enhanced_description = f"{issue_data['description']}\n\n---\n*Created from: {issue_data['source_file']}*"
        cmd_args.extend(['-d', enhanced_description])

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

    if issue_data.get('due_date'):
        cmd_args.extend(['--due-date', issue_data['due_date']])

    # Skip confirmation
    cmd_args.append('-y')

    return run_glab_command(cmd_args)

def find_markdown_files(target_folder):
    """Find all .md files in the target folder."""
    folder_path = Path(target_folder)
    if not folder_path.exists():
        print(f"❌ Error: Folder '{target_folder}' not found")
        return []

    # Find all .md files
    md_files = list(folder_path.glob('*.md'))
    print(f"📁 Found {len(md_files)} markdown files in '{target_folder}':")
    for md_file in md_files:
        print(f"  - {md_file.name}")

    return md_files

def main():
    """Main function to process all markdown files and create issues."""
    # Default folder
    target_folder = 'gitlab'

    # Use command line argument if provided
    if len(sys.argv) > 1:
        target_folder = sys.argv[1]

    print(f"🚀 GitLab Bulk Issue Creator")
    print(f"📂 Target folder: {target_folder}")
    print("-" * 50)

    # Find all markdown files
    md_files = find_markdown_files(target_folder)
    if not md_files:
        print("❌ No markdown files found")
        return

    # Parse all files for issues
    all_issues = []
    file_issue_count = {}

    print(f"\n📝 Parsing markdown files...")
    for md_file in md_files:
        try:
            issues = parse_markdown_issues(md_file)
            if issues:
                all_issues.extend(issues)
                file_issue_count[str(md_file)] = len(issues)
        except Exception as e:
            print(f"  ❌ Error processing {md_file}: {e}")

    if not all_issues:
        print("❌ No issues found in any markdown files")
        return

    # Summary
    print(f"\n📊 Summary:")
    print(f"  Total issues found: {len(all_issues)}")
    for file_path, count in file_issue_count.items():
        print(f"  - {Path(file_path).name}: {count} issues")

    # Group by project and milestone
    projects = {}
    for issue in all_issues:
        project_key = f"{issue['project']} ({issue['milestone'] or 'No milestone'})"
        if project_key not in projects:
            projects[project_key] = []
        projects[project_key].append(issue)

    print(f"\n📋 Issues by project:")
    for project_key, issues in projects.items():
        print(f"  {project_key}: {len(issues)} issues")

    # Confirm before creating
    print(f"\n❓ Proceed to create {len(all_issues)} issues? (y/N): ", end="")
    try:
        response = input().lower()
        if response != 'y':
            print("❌ Aborted.")
            return
    except (EOFError, KeyboardInterrupt):
        print("❌ Aborted.")
        return

    # Create milestones first
    milestones_created = set()
    print(f"\n🎯 Setting up milestones...")
    for issue in all_issues:
        if issue.get('milestone') and issue['milestone'] not in milestones_created:
            create_milestone_if_not_exists(issue['milestone'])
            milestones_created.add(issue['milestone'])

    # Create issues
    print(f"\n🔨 Creating issues...")
    created_issues = []
    failed_issues = []

    for i, issue in enumerate(all_issues, 1):
        print(f"\n[{i}/{len(all_issues)}] Creating: {issue['title']}")
        print(f"  Project: {issue['project']} | File: {Path(issue['source_file']).name}")

        result = create_issue(issue)
        if result:
            print(f"  ✅ Created: {result}")
            created_issues.append({
                'title': issue['title'],
                'url': result,
                'file': Path(issue['source_file']).name
            })
        else:
            print(f"  ❌ Failed: {issue['title']}")
            failed_issues.append(issue)

    # Final summary
    print(f"\n🎉 Bulk Issue Creation Complete!")
    print(f"✅ Successfully created: {len(created_issues)} issues")
    if failed_issues:
        print(f"❌ Failed to create: {len(failed_issues)} issues")

    print(f"\n📋 Created Issues:")
    for issue_info in created_issues:
        print(f"  - {issue_info['title']} [{issue_info['file']}]")
        print(f"    {issue_info['url']}")

if __name__ == "__main__":
    main()