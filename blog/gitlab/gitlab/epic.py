#!/usr/bin/env python3
"""
GitLab Issue Creator from User Stories with Epic Assignment
Creates ONE GitLab issue per user story with tasks as checkboxes and assigns to epic.

Usage: python3 create-story-issues.py [markdown_file_or_folder]
"""

# CONFIGURATION - Hardcoded Epic Assignment
EPIC_ID = None  # Set to epic ID (integer) to assign all issues to that epic, or None to skip
GROUP_ID = None  # Required if using epics - set to your GitLab group ID

import re
import sys
import subprocess
import json
from pathlib import Path

def run_glab_command(cmd_args):
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

def parse_user_story(file_path):
    """Parse user story markdown file and create ONE issue per story."""
    print(f"  📄 Processing user story: {file_path}")

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract story title (first heading)
    title_match = re.search(r'^# (.+)$', content, re.MULTILINE)
    if not title_match:
        print(f"  ⏭️  No story title found in {file_path}")
        return None

    story_title = title_match.group(1)

    # Extract status
    status_match = re.search(r'^## Status\n(.+)$', content, re.MULTILINE)
    status = status_match.group(1).strip() if status_match else "Unknown"

    # Extract story details (As a/I want/So that)
    story_match = re.search(r'\*\*As a\*\* (.+?),\s*\*\*I want\*\* (.+?),\s*\*\*so that\*\* (.+?)\.', content, re.IGNORECASE)

    # Build the issue description
    description = f"## User Story\n"
    if story_match:
        description += f"**As a** {story_match.group(1)}\n"
        description += f"**I want** {story_match.group(2)}\n"
        description += f"**So that** {story_match.group(3)}\n\n"

    description += f"**Status:** {status}\n\n"

    # Extract acceptance criteria
    ac_section = re.search(r'## Acceptance Criteria\n(.*?)(?=^##|\Z)', content, re.MULTILINE | re.DOTALL)
    if ac_section:
        description += f"## Acceptance Criteria\n{ac_section.group(1).strip()}\n\n"

    # Extract tasks/subtasks and convert to checklist format
    tasks_section = re.search(r'## Tasks / Subtasks\n(.*?)(?=^##|\Z)', content, re.MULTILINE | re.DOTALL)
    if tasks_section:
        tasks_content = tasks_section.group(1).strip()
        description += f"## Tasks / Subtasks\n{tasks_content}\n\n"

    # Find everything after the Tasks section and include it all
    tasks_section_match = re.search(r'## Tasks / Subtasks\n(.*?)(?=^##|\Z)', content, re.MULTILINE | re.DOTALL)
    if tasks_section_match:
        # Find where tasks section ends
        tasks_end_pos = tasks_section_match.end()

        # Get all content after tasks section
        remaining_sections = content[tasks_end_pos:].strip()

        if remaining_sections:
            description += f"{remaining_sections}\n\n"

    description += f"---\n*Created from: {file_path}*"

    # Determine labels based on content
    labels = ['user-story']

    # Add labels based on content analysis
    if 'cluster' in content.lower() or 'kubernetes' in content.lower():
        labels.append('kubernetes')
    if 'deployment' in content.lower():
        labels.append('deployment')
    if 'management' in content.lower():
        labels.append('management')
    if 'security' in content.lower():
        labels.append('security')
    if 'monitoring' in content.lower():
        labels.append('monitoring')

    # Estimate weight based on number of tasks
    task_count = len(re.findall(r'^- \[ \]', content, re.MULTILINE))
    if task_count <= 5:
        weight = 5
    elif task_count <= 15:
        weight = 8
    else:
        weight = 10

    # Create milestone name from story
    story_match = re.search(r'Story (\d+\.?\d*)', story_title)
    if story_match:
        milestone_name = f"Story-{story_match.group(1)}"
    else:
        # Fallback to simplified title
        milestone_name = re.sub(r'[^\w\s-]', '', story_title).replace(' ', '-')[:50]

    issue = {
        'title': story_title,
        'description': description,
        'labels': labels,
        'weight': weight,
        'milestone': milestone_name,
        'source_file': str(file_path),
        'task_count': task_count,
        'status': status
    }

    print(f"  ✅ Parsed story: {task_count} tasks, weight {weight}")
    return issue

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
    run_glab_command([
        'api', 'projects/:id/milestones',
        '--method', 'POST',
        '--field', f'title={milestone_name}',
        '--field', f'description=User story milestone: {milestone_name}'
    ])

def assign_issue_to_epic(issue_url, epic_id, group_id):
    """Assign an issue to an epic using GitLab API."""
    if not epic_id or not group_id:
        return False

    # Extract issue ID from URL
    issue_id_match = re.search(r'/issues/(\d+)$', issue_url)
    if not issue_id_match:
        print(f"    ⚠️  Could not extract issue ID from {issue_url}")
        return False

    issue_id = issue_id_match.group(1)

    print(f"    🔗 Assigning issue #{issue_id} to epic #{epic_id}...")

    # Use GitLab API to assign issue to epic
    result = run_glab_command([
        'api', f'groups/{group_id}/epics/{epic_id}/issues/{issue_id}',
        '--method', 'POST'
    ])

    if result:
        print(f"    ✅ Successfully assigned to epic #{epic_id}")
        return True
    else:
        print(f"    ❌ Failed to assign to epic #{epic_id}")
        return False

def create_epic_if_not_exists(epic_title, epic_description, group_id):
    """Create an epic if it doesn't exist."""
    if not group_id:
        print("    ⚠️  No group ID specified - cannot create epic")
        return None

    print(f"  🎯 Checking/creating epic '{epic_title}'...")

    # List existing epics
    result = run_glab_command([f'api', f'groups/{group_id}/epics'])
    if result:
        try:
            epics = json.loads(result)
            existing_epic = next((e for e in epics if e['title'] == epic_title), None)
            if existing_epic:
                print(f"  ✅ Epic '{epic_title}' exists (ID: {existing_epic['id']})")
                return existing_epic['id']
        except json.JSONDecodeError:
            print("  ⚠️  Could not parse epics response")

    # Create epic
    print(f"  🆕 Creating epic '{epic_title}'...")
    result = run_glab_command([
        'api', f'groups/{group_id}/epics',
        '--method', 'POST',
        '--field', f'title={epic_title}',
        '--field', f'description={epic_description}'
    ])

    if result:
        try:
            epic_data = json.loads(result)
            epic_id = epic_data.get('id')
            print(f"  ✅ Created epic '{epic_title}' (ID: {epic_id})")
            return epic_id
        except json.JSONDecodeError:
            print("  ⚠️  Could not parse epic creation response")

    return None

def create_issue(issue_data):
    """Create a GitLab issue using the glab CLI."""
    cmd_args = ['issue', 'create']

    # Required fields
    cmd_args.extend(['-t', issue_data['title']])
    cmd_args.extend(['-d', issue_data['description']])

    # Optional fields
    if issue_data.get('labels'):
        cmd_args.extend(['--label', ','.join(issue_data['labels'])])

    if issue_data.get('milestone'):
        cmd_args.extend(['-m', issue_data['milestone']])

    if issue_data.get('weight'):
        cmd_args.extend(['--weight', str(issue_data['weight'])])

    # Skip confirmation
    cmd_args.append('-y')

    issue_url = run_glab_command(cmd_args)

    # Assign to epic if configured
    if issue_url and EPIC_ID and GROUP_ID:
        assign_issue_to_epic(issue_url, EPIC_ID, GROUP_ID)

    return issue_url

def find_user_story_files(path):
    """Find user story files."""
    path_obj = Path(path)

    if path_obj.is_file():
        return [path_obj]
    elif path_obj.is_dir():
        # Find all .md files that might be user stories
        md_files = list(path_obj.glob('*.md'))
        story_files = []

        for md_file in md_files:
            try:
                with open(md_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Check if it looks like a user story
                    if ('## Tasks / Subtasks' in content and
                        ('**As a**' in content or '**I want**' in content)):
                        story_files.append(md_file)
            except Exception as e:
                print(f"  ⚠️  Error reading {md_file}: {e}")

        return story_files
    else:
        print(f"❌ Error: Path '{path}' not found")
        return []

def main():
    """Main function to process user stories and create issues."""
    # Default path
    target_path = 'gitlab/example.md'

    # Use command line argument if provided
    if len(sys.argv) > 1:
        target_path = sys.argv[1]

    print(f"🚀 GitLab User Story Issue Creator with Epic Assignment")
    print(f"📂 Target path: {target_path}")
    print("📝 Creating ONE issue per user story (not per task)")

    if EPIC_ID and GROUP_ID:
        print(f"🔗 Epic assignment: Enabled (Epic ID: {EPIC_ID}, Group ID: {GROUP_ID})")
    else:
        print("🔗 Epic assignment: Disabled (configure EPIC_ID and GROUP_ID to enable)")

    print("-" * 50)

    # Find user story files
    story_files = find_user_story_files(target_path)
    if not story_files:
        print("❌ No user story files found")
        return

    print(f"📁 Found {len(story_files)} user story files:")
    for story_file in story_files:
        print(f"  - {story_file.name}")

    # Parse all files
    stories = []
    print(f"\n📝 Parsing user story files...")
    for story_file in story_files:
        try:
            story = parse_user_story(story_file)
            if story:
                stories.append(story)
        except Exception as e:
            print(f"  ❌ Error processing {story_file}: {e}")

    if not stories:
        print("❌ No valid user stories found")
        return

    # Summary
    print(f"\n📊 Summary:")
    print(f"  Total stories: {len(stories)}")
    for story in stories:
        print(f"  - {story['title']}: {story['task_count']} tasks, weight {story['weight']}")

    # Confirm before creating
    print(f"\n❓ Create {len(stories)} GitLab issues (one per story)? (y/N): ", end="")
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
    for story in stories:
        if story.get('milestone') and story['milestone'] not in milestones_created:
            create_milestone_if_not_exists(story['milestone'])
            milestones_created.add(story['milestone'])

    # Create issues
    print(f"\n🔨 Creating GitLab issues...")
    created_issues = []
    failed_issues = []

    for i, story in enumerate(stories, 1):
        print(f"\n[{i}/{len(stories)}] Creating story issue: {story['title']}")
        print(f"  Tasks: {story['task_count']} | Weight: {story['weight']} | File: {Path(story['source_file']).name}")

        result = create_issue(story)
        if result:
            print(f"  ✅ Created: {result}")
            created_issues.append({
                'title': story['title'],
                'url': result,
                'milestone': story.get('milestone', 'Unknown'),
                'file': Path(story['source_file']).name,
                'task_count': story['task_count']
            })
        else:
            print(f"  ❌ Failed: {story['title']}")
            failed_issues.append(story)

    # Final summary
    print(f"\n🎉 User Story Issue Creation Complete!")
    print(f"✅ Successfully created: {len(created_issues)} issues")
    if failed_issues:
        print(f"❌ Failed to create: {len(failed_issues)} issues")

    print(f"\n📋 Created Issues:")
    for issue_info in created_issues:
        print(f"  - {issue_info['title']} ({issue_info['task_count']} tasks)")
        print(f"    {issue_info['url']}")

if __name__ == "__main__":
    main()