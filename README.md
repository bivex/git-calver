# git-version

`git-version` is a small Bash CLI for CalVer-style versioning in a git repository.

It manages:

- `VERSION.txt`
- `CHANGELOG.md`
- annotated git tags like `v2026.03.21`

Version format:

- `vYYYY.MM.DD`
- `vYYYY.MM.DD-N` for additional releases on the same day

Dates are generated in UTC.

## What it does

- reads conventional commit subjects
- calculates the next version from git history
- updates `VERSION.txt`
- prepends a changelog entry to `CHANGELOG.md`
- creates release tags
- can create a release commit and optionally push it

## Requirements

- `bash`
- `git`
- `date`

## Install

From this repository:

```bash
git clone <this-repo> git-version
cd git-version
./install.sh
```

By default the script installs:

- binary to `~/.local/bin/git-version`
- libraries to `~/.local/lib/`
- hook templates to `~/.local/share/git-version/hooks/`

You can override the target directory:

```bash
INSTALL_DIR=/usr/local/bin ./install.sh
```

## Use in a New Project

Minimal setup:

```bash
cd /path/to/your/project
git-version init
```

`init` creates:

- `VERSION.txt`
- `CHANGELOG.md`
- the first annotated tag if the repository does not already have one

### Recommended integration

For a new repository, there are two practical ways to use the tool.

#### 1. Explicit release flow

Use `git-version release` when you want to cut a release:

```bash
git commit -m "feat: add API endpoint"
git-version release
```

Or push immediately:

```bash
git-version release --push
```

This is the simplest and least surprising workflow.

#### 2. Hook-based local automation

If you want local auto-bump behavior after commits:

```bash
git-version hooks install
```

This installs hook templates into the current clone’s `.git/hooks`.

Important:

- `.git/hooks` is local and is not versioned by git
- if you want hooks to survive fresh clones, keep them in a tracked directory such as `.githooks/`
- then point git to them with `git config core.hooksPath .githooks`

Typical setup for a versioned hook directory:

```bash
mkdir -p .githooks
cp ~/.local/share/git-version/hooks/post-commit .githooks/post-commit
cp ~/.local/share/git-version/hooks/pre-push .githooks/pre-push
chmod +x .githooks/post-commit .githooks/pre-push
git config core.hooksPath .githooks
```

## Commands

### `git-version current`

Prints the current version from `VERSION.txt` or the latest matching tag.

### `git-version next`

Prints the version that would be produced next without changing files.

If there are no unreleased commits, it prints the current version.

### `git-version bump [major|minor|patch|force]`

Prepares the next version locally.

Current behavior:

- updates `VERSION.txt`
- updates `CHANGELOG.md`
- stages those files
- creates an annotated tag unless `--no-tag` is used
- does not create the release commit for you

Use this if you want to control the commit step manually.

### `git-version release [type] [--push] [--remote <name>]`

Recommended release command.

Current behavior:

- requires a clean worktree
- updates `VERSION.txt`
- updates `CHANGELOG.md`
- creates a release commit
- creates an annotated tag
- optionally pushes the current branch and reachable tags

If there are no unreleased commits and no explicit bump type is given, it exits without creating a new release.

Examples:

```bash
git-version release
git-version release patch
git-version release --push
git-version release minor --push --remote origin
```

### `git-version changelog [since]`

Prints changelog content derived from commit history.

### `git-version init`

Initializes version files and creates the first tag if one does not exist.

### `git-version hooks install|uninstall`

Installs or removes the shipped hook templates in the current clone.

### `git-version validate <commit-subject>`

Checks whether a commit subject matches the expected conventional format.

## Conventional Commit Handling

Conventional commit subjects are used for validation and changelog grouping.

Accepted patterns that the tool treats specially:

| Commit form | Meaning |
|-------------|---------|
| `feat!:` or `BREAKING CHANGE:` | marked as breaking in changelog |
| `feat:` | grouped under `Added` |
| `fix:`, `perf:`, `refactor:` | grouped under `Fixed` or `Changed` |
| `bump: major|minor|patch|force` | explicit release override |

Examples:

```bash
git commit -m "feat: add user authentication"
git commit -m "fix: handle timeout"
git commit -m "feat(api)!: remove deprecated endpoint"
git commit -m "bump: patch"
```

## Files

### `VERSION.txt`

Stores the current version:

```text
v2026.03.21
```

### `CHANGELOG.md`

Receives generated entries grouped by commit category.

## Notes and Limits

- The tool uses git tags as release markers.
- The version format is always CalVer: `vYYYY.MM.DD` or `vYYYY.MM.DD-N`.
- `major`, `minor`, and `patch` are accepted inputs, but they do not produce different version shapes the way SemVer does.
- Any unreleased commits can advance the version; conventional commit types mainly improve classification and validation.
- If you auto-update versions locally without creating tags, later behavior depends on your hook workflow.
- `release` is the most reliable command for end-to-end releases.
- The shipped hook templates are a starting point, not a universal policy for every repository.

## License

MIT
