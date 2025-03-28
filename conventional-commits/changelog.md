# Implementing Conventional Commits for Automated Changelog Management

This guide outlines our complete implementation strategy for adopting conventional commits across our engineering team to improve changelog management in GitLab.

## Table of Contents
1. [Defining Our Commit Convention](#1-defining-our-commit-convention)
2. [Commit Message Template](#2-commit-message-template)
3. [Team-Wide Git Configuration](#3-team-wide-git-configuration)
4. [Merge Request Template](#4-merge-request-template)
5. [Commit Validation with GitLab CI](#5-commit-validation-with-gitlab-ci)
6. [Automated Changelog Generation](#6-automated-changelog-generation)
7. [Developer Guidelines](#7-developer-guidelines)
8. [Team Onboarding](#8-team-onboarding)

## 1. Defining Our Commit Convention

We're adopting the [Conventional Commits](https://www.conventionalcommits.org/) standard with the following format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type | Description | Changelog Section |
|------|-------------|-------------------|
| `feat` | A new feature | Features |
| `fix` | A bug fix | Bug Fixes |
| `docs` | Documentation only changes | Documentation |
| `style` | Changes that don't affect code (formatting, etc.) | Other Changes |
| `refactor` | Code changes that neither fix bugs nor add features | Other Changes |
| `perf` | Performance improvements | Performance Improvements |
| `test` | Adding or updating tests | Other Changes |
| `chore` | Changes to build process, dependencies, etc. | Other Changes |

### Real-World Examples

**Feature Addition:**
```
feat(auth): implement multi-factor authentication

Added support for authenticator apps and SMS verification.
This completes the security roadmap item SEC-42.
```

**Bug Fix:**
```
fix(api): prevent race condition in payment processing

Fixed concurrent API calls causing duplicate transactions.

Fixes: #387
```

**Breaking Change:**
```
feat(api): restructure response format for all endpoints

BREAKING CHANGE: All API responses now use the new standardized format.
Client applications will need to be updated to parse the new structure.
```

## 2. Commit Message Template

Place this template in your repository root as `.gitmessage`:

```
# <type>(<scope>): <short summary>
# |       |             |
# |       |             +-> Summary in present tense (50 chars or less)
# |       +----------------> Optional scope: module/component affected
# +--------------------------> Type: feat, fix, docs, style, refactor, perf, test, chore
#
# Optional body: explain WHAT and WHY, not HOW (wrap at 72 chars)
#
# Optional footer:
# - Breaking changes (BREAKING CHANGE: <description>)
# - References to issues (Fixes: #123)
# - Note deprecated features (Deprecated: <description>)
#
# Types:
# feat:     A new feature
# fix:      A bug fix
# docs:     Documentation changes
# style:    Code style/formatting changes (no functional change)
# refactor: Code refactoring (no functional change)
# perf:     Performance improvements
# test:     Adding or updating tests
# chore:    Tooling, dependency updates, etc.
```

## 3. Team-Wide Git Configuration

### Individual Setup

Each team member should run:

```bash
git config --global commit.template /path/to/.gitmessage
```

For a repository-specific setup:

```bash
git config commit.template .gitmessage
```

### Helpful Git Aliases

Consider adding these aliases to your global Git config:

```bash
git config --global alias.cm "commit -m"
git config --global alias.cf "commit --file .gitmessage"
```

## 4. Merge Request Template

Create a file at `.gitlab/merge_request_templates/Default.md`:

```markdown
## Description
<!-- Provide a clear description of the changes in this MR -->

## Changelog Entry
<!-- Please add a changelog entry that follows the conventional format -->
<!-- Example: feat(auth): implement multi-factor authentication -->

## Type of Change
<!-- Please check the one that applies using [x] -->
- [ ] feat: A new feature
- [ ] fix: A bug fix
- [ ] docs: Documentation only changes
- [ ] style: Changes that do not affect the meaning of the code
- [ ] refactor: A code change that neither fixes a bug nor adds a feature
- [ ] perf: A code change that improves performance
- [ ] test: Adding missing tests or correcting existing tests
- [ ] chore: Changes to the build process or auxiliary tools

## Breaking Changes
<!-- Does this MR introduce breaking changes? If yes, please describe. -->

## Related Issues
<!-- Link any related issues here using #issue_number -->
```

## 5. Commit Validation with GitLab CI

Add this to your `.gitlab-ci.yml` file:

```yaml
stages:
  - validate
  - build
  - test
  - deploy

validate-commit-messages:
  stage: validate
  image: node:latest
  before_script:
    - npm install -g @commitlint/cli @commitlint/config-conventional
    - echo "module.exports = {extends: ['@commitlint/config-conventional']}" > commitlint.config.js
  script:
    - git log -1 --pretty=format:%B | commitlint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

Additionally, create a `commitlint.config.js` file in your repository:

```javascript
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // You can customize rules here
    'scope-enum': [2, 'always', [
      'auth', 'api', 'ui', 'db', 'core', 'config', 'deps'
      // Add your project-specific scopes
    ]]
  }
};
```

## 6. Automated Changelog Generation

Add this job to your `.gitlab-ci.yml`:

```yaml
update-changelog:
  stage: deploy
  image: node:latest
  before_script:
    - npm install -g conventional-changelog-cli
    - git config --global user.name "${GITLAB_USER_NAME}"
    - git config --global user.email "${GITLAB_USER_EMAIL}"
  script:
    # Generate changelog
    - conventional-changelog -p angular -i CHANGELOG.md -s
    # Commit and push if there are changes
    - |
      if [[ -n "$(git status --porcelain CHANGELOG.md)" ]]; then
        git add CHANGELOG.md
        git commit -m "chore: update CHANGELOG.md [skip ci]"
        git push https://oauth2:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git HEAD:${CI_COMMIT_REF_NAME}
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

Create an initial CHANGELOG.md file:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
```

## 7. Developer Guidelines

Create a `CONTRIBUTING.md` file with these guidelines:

```markdown
# Contributing Guidelines

## Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for our commit messages. This leads to more readable messages that are easy to follow when looking through the project history and automatically generates our changelog.

### Format

```
<type>(<scope>): <short summary>
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect code functionality (formatting, etc.)
- **refactor**: Code changes that neither fix bugs nor add features
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Changes to build process, dependencies, etc.

### Scope

The scope is optional and represents the module affected by the change.

Examples: `auth`, `api`, `ui`, `db`, etc.

### Summary

- Write in present tense ("add feature" not "added feature")
- Don't capitalize the first letter
- No period at the end
- Keep it under 50 characters

### Examples

```
feat(auth): implement JWT authentication
fix(api): resolve null reference in user lookup
docs(readme): update installation instructions
perf(queries): optimize database access
```

### Breaking Changes

For breaking changes, add `BREAKING CHANGE:` in the commit body or footer:

```
feat(api): change response format for user endpoints

BREAKING CHANGE: The response format has changed from XML to JSON
```
```

## 8. Team Onboarding

### Rollout Plan

1. **Announce the Change**
   - Schedule a team meeting to introduce the conventional commits workflow
   - Share the README and provide time for questions
   - Set a start date for implementation

2. **Training Session**
   - Schedule a 30-minute training session
   - Walk through examples and the workflow
   - Demonstrate how to use the template and tools

3. **Gradual Implementation**
   - Week 1: Encourage team members to try conventional commits without strict enforcement
   - Week 2: Enable the CI validation but allow MRs even with validation failures
   - Week 3: Full implementation with validation requirements

4. **Support System**
   - Designate a team member as the "Conventional Commits Champion"
   - Set up a Slack/Teams channel for questions and help
   - Schedule follow-up sessions to address challenges

### Handling Common Issues

**"I forgot to follow the convention"**
- Use `git commit --amend` to fix the most recent commit
- For older commits, use interactive rebase: `git rebase -i HEAD~n`

**"What scope should I use?"**
- Refer to the scope guidelines in the contributing document
- When in doubt, omit the scope rather than using an inappropriate one

**"My commit spans multiple types"**
- Split your changes into multiple commits, each with a single purpose
- If not possible, use the most significant type that applies

## Before & After Examples

### Before Implementation

Inconsistent commit messages:
```
Fixed login bug
updated styles on dashboard
Add CSV export feature
docs update
```

### After Implementation

Clear, structured commit messages:
```
fix(auth): resolve login failure with special characters in password
style(dashboard): align elements according to design system
feat(reports): add CSV export functionality
docs(api): add examples for new endpoints
```

## Benefits We'll See

1. **Automated Changelog Generation**
   - No more manual changelog updates
   - Consistent format across all releases

2. **Better Code Reviews**
   - Clear purpose for each commit
   - Easier to understand the intent of changes

3. **Improved Release Management**
   - Automated semantic versioning decisions
   - Clear breakdown of features, fixes, and breaking changes

4. **Historical Context**
   - Better understanding of why changes were made
   - Improved debugging and maintenance

---

## Implementation Checklist

- [ ] Add commit message template to repository
- [ ] Configure GitLab CI for validation
- [ ] Create merge request template
- [ ] Set up automated changelog generation
- [ ] Add contributing guidelines
- [ ] Schedule team training
- [ ] Begin phased rollout
- [ ] Review and adjust after 30 days