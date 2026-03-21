# git-version

Calendar-based versioning (CalVer) for git repositories with automatic changelog generation.

## Features

- **Calendar versioning**: Versions based on dates (YYYY.MM.DD) with daily increments
- **Conventional commits**: Parses conventional commit messages to determine version changes
- **Automatic changelog**: Generates `CHANGELOG.md` from commit history
- **Git hooks**: Optional auto-versioning on commits
- **Force bumps**: Override automatic detection with `bump:` commits
- **Breaking changes**: Automatic detection of breaking changes

## Installation

```bash
# Clone and install
git clone https://github.com/yourusername/git-version.git /Volumes/External/Code/git_verisoner
cd /Volumes/External/Code/git_verisoner
./install.sh

# Or install to specific directory
INSTALL_DIR=/usr/local/bin ./install.sh
```

## Quick Start

```bash
# Initialize in your repository
git-version init

# Make some commits
git commit -m "feat: add new feature"

# Release in one command (updates files, creates release commit, and tags it)
git-version release

# Show current version
git-version current

# Generate changelog
git-version changelog
```

## Version Format

Versions follow the calendar format: **YYYY.MM.DD[-N]**

- `2025.03.19` - First release on March 19, 2025
- `2025.03.19-1` - Second release on the same day
- `2025.03.19-2` - Third release on the same day

All versions are prefixed with `v` in git tags (e.g., `v2025.03.19`).

## Conventional Commits

git-version follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

| Type | Bump Level | Description |
|------|------------|-------------|
| `feat!` or `BREAKING CHANGE:` | Major | Breaking change |
| `feat:` | Minor | New feature |
| `fix:`, `perf:`, `refactor:` | Patch | Bug fixes, improvements |

### Examples

```bash
git commit -m "feat: add user authentication"
git commit -m "feat(auth)!: remove deprecated API"
git commit -m "fix: handle null pointer exception"
git commit -m "BREAKING CHANGE: migrate to new API format"
```

## Commands

### `git-version current`

Show the current version from `VERSION.txt` or git tags.

```bash
git-version current
# v2025.03.19
```

### `git-version next`

Show what the next version would be without applying it.

```bash
git-version next
# v2025.03.19

git-version next
# Previous version: v2025.03.18
# Commits since last version:
#   - feat: add new feature
```

### `git-version bump [type]`

Prepare the next version manually. This updates release files and creates a tag, but leaves the release commit to you.

```bash
# Auto-detect bump level from commits
git-version bump

# Force a specific bump level
git-version bump major   # Breaking change
git-version bump minor   # New feature
git-version bump patch   # Bug fix

# Bump without creating a tag
git-version --no-tag bump
```

### `git-version release [type] [--push]`

Create the release end-to-end in one command.

```bash
# Create VERSION.txt / CHANGELOG.md updates, commit them, and tag the release
git-version release

# Force a specific release type
git-version release patch

# Release and push the current branch with tags
git-version release --push
```

### `git-version changelog [since]`

Generate changelog from commit history.

```bash
# Changelog since last version
git-version changelog

# Changelog since a specific date
git-version changelog 2025.01.01
```

### `git-version init`

Initialize versioning in a new repository.

```bash
git-version init
# Creates VERSION.txt, CHANGELOG.md, and initial git tag
```

### `git-version hooks install|uninstall`

Install or uninstall git hooks.

```bash
# Install hooks (auto-bump on breaking changes, validate on push)
git-version hooks install

# Uninstall hooks
git-version hooks uninstall
```

### `git-version validate <commit>`

Validate a conventional commit message.

```bash
git-version validate "feat: add new feature"
# Valid conventional commit

git-version validate "added feature"
# error: commit must follow conventional commit format
```

## Force Bumps

You can force a version bump using `bump:` commits:

```bash
git commit -m "bump: major"
git commit -m "bump: minor"
git commit -m "bump: patch"
git commit -m "bump: force"
```

## Configuration

Configuration can be set via environment variables or a config file:

```bash
# Environment variables
export VERSION_FILE=VERSION.txt
export CHANGELOG_FILE=CHANGELOG.md
export VERBOSITY=2
```

Or create a `git-version.conf` file in your project root:

```bash
# Copy default config
cp /Volumes/External/Code/git_verisoner/config/git-version.conf ./git-version.conf
```

## Git Hooks

### Post-commit Hook

Automatically stages updated release files after commits when the version changes:

```bash
# After committing a breaking change
git commit -m "feat!: remove deprecated API"

# VERSION.txt is automatically updated (staged for next commit)
```

### Pre-push Hook

Validates that a version tag exists before pushing:

```bash
git push
# Error: Tag v2025.03.19 does not exist
# Run 'git-version release' to create the release commit and tag
```

## Workflow Examples

### Standard Workflow

```bash
# 1. Initialize
git-version init

# 2. Make commits
git commit -m "feat: add new feature"
git commit -m "fix: handle edge case"

# 3. Release
git-version release --push
# Updates VERSION.txt and CHANGELOG.md
# Creates commit chore: release v2025.03.19
# Creates git tag v2025.03.19
# Pushes branch and tag
```

### Breaking Change Workflow

```bash
# 1. Make breaking change
git commit -m "feat!: remove deprecated endpoint"

# 2. Post-commit hook can pre-stage release files (if installed)

# 3. Finalize the release
git-version release
```

### Multiple Releases Per Day

```bash
# Morning release
git commit -m "feat: add feature A"
git-version release
# VERSION.txt: v2025.03.19 and tag created

# Afternoon release
git commit -m "feat: add feature B"
git-version release
# VERSION.txt: v2025.03.19-1 and tag created

# Evening release
git commit -m "fix: critical bug"
git-version release
# VERSION.txt: v2025.03.19-2 and tag created
```

## Output Files

### VERSION.txt

Contains the current version:

```
v2025.03.19
```

### CHANGELOG.md

Auto-generated changelog with sections:

```markdown
# Changelog

## [v2025.03.19] - 2025-03-19

### Breaking Changes
- **auth**: Removed deprecated API endpoint (a1b2c3d)

### Added
- Add user authentication (e4f5g6h)
- Add rate limiting (i7j8k9l)

### Fixed
- Handle null pointer exception (m0n1o2p)
```

## Timezones

All dates are calculated using **UTC** to ensure consistency across different environments.

## Integration

### CI/CD

```yaml
# GitHub Actions example
- name: Create release
  run: git-version release --push
```

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
git-version validate "$(cat $1)"
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
