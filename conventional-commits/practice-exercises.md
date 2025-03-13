# Conventional Commit Practice Exercises

These exercises will help you practice writing conventional commit messages. Each scenario describes a change you've made to a project. Your task is to write an appropriate conventional commit message.

## How to Use These Exercises

1. Read each scenario
2. Craft a commit message following the conventional commits format
3. Check the solution (but try to solve it yourself first!)

## Exercises

### Exercise 1: Adding a New Feature
**Scenario:** You've added a new user registration form to the application.

**Your task:** Write a commit message for this change.

<details>
<summary>Solution</summary>

```
feat(auth): add user registration form
```

or with more details:

```
feat(auth): add user registration form

Implement a registration form with email, password, and confirmation fields.
Form includes client-side validation and submits to the /api/register endpoint.
```
</details>

### Exercise 2: Fixing a Bug
**Scenario:** You've fixed a bug where the app would crash when a user tried to login with an empty password field.

**Your task:** Write a commit message for this bug fix.

<details>
<summary>Solution</summary>

```
fix(auth): prevent crash on empty password login
```

or with more details:

```
fix(auth): prevent crash on empty password login

Add validation check to ensure password is not empty before
attempting authentication. Returns appropriate error message
to the user instead of crashing.
```
</details>

### Exercise 3: Making a Breaking Change
**Scenario:** You've updated the authentication system to use JWT tokens instead of session cookies, which will require clients to update their code.

**Your task:** Write a commit message for this breaking change.

<details>
<summary>Solution</summary>

```
feat(auth)!: replace session cookies with JWT tokens

BREAKING CHANGE: Authentication now uses JWT tokens instead of
session cookies. Clients need to extract the token from the
Authorization header and include it in subsequent requests.
```

Alternative format:

```
feat(auth): replace session cookies with JWT tokens

BREAKING CHANGE: Authentication now uses JWT tokens instead of
session cookies. Clients need to extract the token from the
Authorization header and include it in subsequent requests.
```
</details>

### Exercise 4: Updating Documentation
**Scenario:** You've updated the installation instructions in the README file.

**Your task:** Write a commit message for this documentation update.

<details>
<summary>Solution</summary>

```
docs: update installation instructions
```

or with more details:

```
docs: update installation instructions

Add Docker setup steps and update Node.js version requirements.
Clarify environment variable configuration process.
```
</details>

### Exercise 5: Code Refactoring
**Scenario:** You've refactored the data fetching logic to use async/await instead of promises.

**Your task:** Write a commit message for this refactoring.

<details>
<summary>Solution</summary>

```
refactor(api): convert promise chains to async/await
```

or with more details:

```
refactor(api): convert promise chains to async/await

Replace all promise chain syntax (.then/.catch) with more
readable async/await pattern throughout the API service.
No functional changes.
```
</details>

### Exercise 6: Performance Improvement
**Scenario:** You've optimized the image loading process to improve page load times.

**Your task:** Write a commit message for this performance improvement.

<details>
<summary>Solution</summary>

```
perf(images): implement lazy loading for gallery images
```

or with more details:

```
perf(images): implement lazy loading for gallery images

Add intersection observer to only load images when they
come into viewport. Reduced initial page load size by 60%.
```
</details>

### Exercise 7: Adding Tests
**Scenario:** You've added unit tests for the user authentication component.

**Your task:** Write a commit message for adding these tests.

<details>
<summary>Solution</summary>

```
test(auth): add unit tests for user authentication
```

or with more details:

```
test(auth): add unit tests for user authentication

Add comprehensive test suite for login, logout, and
password reset functionality. Includes both success
and failure test cases.
```
</details>

### Exercise 8: Multiple Changes in One Commit
**Scenario:** You've fixed a bug in the login form and also updated its styling.

**Your task:** Write a commit message for these changes.

<details>
<summary>Solution</summary>

Since this involves two different types of changes, you have a few options:

Option 1 (focus on the more important change, the bug fix):
```
fix(auth): resolve login form submission errors and update styling
```

Option 2 (separate commits would be better in this case):
```
fix(auth): resolve login form submission errors
```
and
```
style(auth): update login form appearance
```
</details>

### Exercise 9: Dependencies Update
**Scenario:** You've updated several npm packages in package.json.

**Your task:** Write a commit message for updating dependencies.

<details>
<summary>Solution</summary>

```
build(deps): update npm dependencies
```

or with more details:

```
build(deps): update npm dependencies

Update React from 17.0.2 to 18.0.0
Update TypeScript from 4.4.3 to 4.6.2
Update testing-library packages to latest versions
```
</details>

### Exercise 10: Reverting a Previous Commit
**Scenario:** You need to revert a problematic commit (commit hash abc1234) that introduced a critical bug.

**Your task:** Write a commit message for this revert.

<details>
<summary>Solution</summary>

```
revert: feat(auth) add biometric login

This reverts commit abc1234, which introduced compatibility
issues with older devices.
```
</details>

## Real-World Practice

After completing these exercises, try applying conventional commits to your actual projects:

1. Create a small project or clone an existing one
2. Make several changes, covering different types (feat, fix, docs, etc.)
3. Create commits with proper conventional commit messages
4. Use tools like commitlint and commitizen to help format your messages

Remember that consistent use of conventional commits makes your project history more navigable and enables automated changelog generation. 