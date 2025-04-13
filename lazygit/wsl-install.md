# LazyGit: Installation and Usage Guide for Mac

LazyGit is a powerful terminal UI for Git that simplifies complex operations and enhances your Git workflow directly from the command line.

## Installation

On macOS, the recommended installation method is using Homebrew:

```bash
brew install jesseduffield/lazygit/lazygit
```

This tap version is recommended for frequent updates.

## Getting Started

To use LazyGit, navigate to any Git repository in your terminal and run:

```bash
lazygit
```

## Interface Overview

When you launch LazyGit, you'll see a well-organized interface with several panels:

- **Status Bar** (Top): Shows current branch information
- **Files Panel** (Position 2): Displays modified/staged files
- **Branches Panel** (Position 3): Shows local branches
- **Commits Panel** (Position 4): Displays commit history
- **Stash Panel**: Shows stashed changes

Navigate between panels using the number keys (2 for Files, 3 for Branches, 4 for Commits).

## Key Features and Commands

### Basic Navigation
- **Arrow keys/HJKL**: Move around
- **Tab**: Switch between panels
- **?**: Show keybindings help
- **/**: Search in help menu
- **Esc**: Go back/exit current view

### Branch Management
- **n**: Create new branch
- **Spacebar**: Checkout selected branch
- **Capital M**: Merge selected branch
- **u**: View upstream options

### Staging and Committing
- **Spacebar**: Stage/unstage selected file
- **a**: Stage all files
- **Enter on file**: View changes in detail
- **Spacebar in diff view**: Stage/unstage individual hunks
- **c**: Commit staged changes
- **w**: Commit without pre-commit hook

### Pushing and Pulling
- **Capital P**: Push to remote
- **p**: Pull from remote

### Commit Manipulation
- **r**: Reword commit message
- **s**: Squash selected commits
- **i**: Start interactive rebase
- **g**: Reset to commit (in upstream divergence view)

### Merge Conflict Resolution
1. When a merge conflict occurs, LazyGit will show conflicts
2. Use **Enter** to view conflicted files
3. Navigate between conflicts with **left/right** arrow keys
4. Use **Spacebar** to select the version you want to keep
5. Press **Enter** to complete the merge when all conflicts are resolved

### View Modes
- **Shift + Plus (+)**: Expand view
- **Shift + Minus (-)**: Reduce view

### Advanced Features
- **Multiple commit selection**: Use **Shift + arrow keys** to select multiple commits
- **Squashing**: Select commits and press **s**
- **Interactive rebasing**: Press **i** in the commits panel
- **Bisecting**: Full support for Git bisect
- **Cherry-picking**: Easily cherry-pick commits with visual interface

## Tips and Tricks

- Use **Page Up/Down** or the mouse wheel to scroll through diffs
- For force push situations, use **Capital P** after rebasing/amending
- LazyGit shows commits in yellow if they're not on the main branch and red if they're not on the upstream branch
- Press **Escape** multiple times to return to the main view

## Further Resources

- Official GitHub Repository: [jesseduffield/lazygit](https://github.com/jesseduffield/lazygit)
- Full Documentation: [LazyGit Wiki](https://github.com/jesseduffield/lazygit/wiki)

With LazyGit, complex Git operations like partial staging, interactive rebasing, and conflict resolution become much more intuitive and manageable through a user-friendly terminal interface.