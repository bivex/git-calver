#!/usr/bin/env bash
# git-version conventional commits parser
# Parses conventional commits and identifies version bump requirements

# Source utility functions
# shellcheck source=./lib/utils.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Source git functions
# shellcheck source=./lib/git.sh
source "${SCRIPT_DIR}/git.sh"

# Conventional commit types
readonly TYPE_FEAT="feat"
readonly TYPE_FIX="fix"
readonly TYPE_PERF="perf"
readonly TYPE_REFACTOR="refactor"
readonly TYPE_DOCS="docs"
readonly TYPE_TEST="test"
readonly TYPE_BUILD="build"
readonly TYPE_CI="ci"
readonly TYPE_CHORE="chore"
readonly TYPE_STYLE="style"

# Bump levels
readonly BUMP_MAJOR="major"
readonly BUMP_MINOR="minor"
readonly BUMP_PATCH="patch"
readonly BUMP_NONE="none"

# Parse commit subject to extract type and scope
parse_commit_type() {
    local subject="$1"
    # Extract type (word before colon)
    echo "$subject" | sed -E 's/^([a-z]+)(\(.+\))?!?:.*/\1/'
}

# Parse commit subject to extract scope
parse_commit_scope() {
    local subject="$1"
    # Extract scope (between parentheses)
    echo "$subject" | sed -nE 's/^[a-z]+\((.+)\)!?:.*/\1/p'
}

# Parse commit subject to extract breaking indicator
parse_commit_breaking() {
    local subject="$1"
    # Check for ! after scope/type or before :
    if echo "$subject" | grep -qE '^[a-z]+(\(.+\))?!:'; then
        echo "true"
    else
        echo "false"
    fi
}

# Parse commit subject to extract description
parse_commit_description() {
    local subject="$1"
    # Extract description (after colon)
    echo "$subject" | sed -E 's/^[a-z]+(\(.+\))?!?: //'
}

# Check if commit is a conventional commit
is_conventional_commit() {
    local subject="$1"
    # Match: type(scope)!: description or type!: description or type: description
    echo "$subject" | grep -qE '^[a-z]+(\(.+\))?!?: .+'
}

# Check if commit has breaking change
is_breaking_change() {
    local subject="$1"
    local commit_hash="$2"

    # Check subject for !
    if [ "$(parse_commit_breaking "$subject")" = "true" ]; then
        return 0
    fi

    # Check body for BREAKING CHANGE:
    if [ -n "$commit_hash" ] && has_breaking_change_footer "$commit_hash"; then
        return 0
    fi

    return 1
}

# Check if commit is a force bump commit (bump: type)
is_force_bump_commit() {
    local subject="$1"
    echo "$subject" | grep -qE '^bump:( (major|minor|patch|force))?'
}

# Parse force bump type from commit
parse_force_bump_type() {
    local subject="$1"

    if echo "$subject" | grep -qE '^bump: force'; then
        echo "$BUMP_MAJOR"
    elif echo "$subject" | grep -qE '^bump: major'; then
        echo "$BUMP_MAJOR"
    elif echo "$subject" | grep -qE '^bump: minor'; then
        echo "$BUMP_MINOR"
    elif echo "$subject" | grep -qE '^bump: patch'; then
        echo "$BUMP_PATCH"
    else
        echo "$BUMP_NONE"
    fi
}

# Get bump level for a single commit
get_commit_bump_level() {
    local subject="$1"
    local commit_hash="$2"

    # Check for force bump
    if is_force_bump_commit "$subject"; then
        parse_force_bump_type "$subject"
        return
    fi

    # Check if it's a conventional commit
    if ! is_conventional_commit "$subject"; then
        echo "$BUMP_NONE"
        return
    fi

    local type
    type=$(parse_commit_type "$subject")

    # Check for breaking change
    if is_breaking_change "$subject" "$commit_hash"; then
        echo "$BUMP_MAJOR"
        return
    fi

    # Map types to bump levels
    case "$type" in
        $TYPE_FEAT)
            echo "$BUMP_MINOR"
            ;;
        $TYPE_FIX|$TYPE_PERF|$TYPE_REFACTOR)
            echo "$BUMP_PATCH"
            ;;
        *)
            echo "$BUMP_NONE"
            ;;
    esac
}

# Get the highest bump level from a set of commits
get_max_bump_level() {
    local commits="$1"
    local max_level="$BUMP_NONE"

    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue

        local bump_level
        bump_level=$(get_commit_bump_level "$subject" "$hash")

        # Update max level (major > minor > patch > none)
        case "$bump_level" in
            $BUMP_MAJOR)
                max_level="$BUMP_MAJOR"
                break  # Can't go higher than major
                ;;
            $BUMP_MINOR)
                if [ "$max_level" != "$BUMP_MAJOR" ]; then
                    max_level="$BUMP_MINOR"
                fi
                ;;
            $BUMP_PATCH)
                if [ "$max_level" = "$BUMP_NONE" ]; then
                    max_level="$BUMP_PATCH"
                fi
                ;;
        esac
    done <<< "$commits"

    echo "$max_level"
}

# Check if commits have breaking changes
has_breaking_changes() {
    local commits="$1"

    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue
        if is_breaking_change "$subject" "$hash"; then
            return 0
        fi
    done <<< "$commits"

    return 1
}

# Check if commits have force bump
has_force_bump() {
    local commits="$1"

    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue
        if is_force_bump_commit "$subject"; then
            return 0
        fi
    done <<< "$commits"

    return 1
}

# Categorize commit for changelog
categorize_commit() {
    local subject="$1"
    local commit_hash="$2"

    if ! is_conventional_commit "$subject"; then
        echo "other"
        return
    fi

    local type
    type=$(parse_commit_type "$subject")

    if is_breaking_change "$subject" "$commit_hash"; then
        echo "breaking"
        return
    fi

    case "$type" in
        $TYPE_FEAT)
            echo "added"
            ;;
        $TYPE_FIX)
            echo "fixed"
            ;;
        $TYPE_PERF|$TYPE_REFACTOR)
            echo "changed"
            ;;
        $TYPE_DOCS)
            echo "docs"
            ;;
        $TYPE_TEST|$TYPE_BUILD|$TYPE_CI|$TYPE_CHORE|$TYPE_STYLE)
            echo "internal"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Format commit for changelog display
format_commit_for_changelog() {
    local subject="$1"
    local commit_hash="$2"
    local scope
    scope=$(parse_commit_scope "$subject")
    local description
    description=$(parse_commit_description "$subject")

    # Add scope if present
    if [ -n "$scope" ]; then
        description="**${scope}**: ${description}"
    fi

    # Add commit hash reference
    local short_hash
    short_hash=$(echo "$commit_hash" | cut -c1-7)
    description="${description} (${short_hash})"

    echo "$description"
}

# Get breaking change description
get_breaking_change_description() {
    local commit_hash="$1"
    local body
    body=$(get_commit_body "$commit_hash")

    # Extract BREAKING CHANGE: content
    local breaking_content
    breaking_content=$(echo "$body" | sed -n '/BREAKING CHANGE:/,/^[A-Z]/p' | sed '1d;$d')

    if [ -z "$breaking_content" ]; then
        # Use commit subject if no detailed breaking change
        local subject
        subject=$(get_commit_subject "$commit_hash")
        parse_commit_description "$subject"
    else
        echo "$breaking_content"
    fi
}

# Group commits by category for changelog
group_commits_by_category() {
    local commits="$1"
    declare -A groups

    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue

        local category
        category=$(categorize_commit "$subject" "$hash")
        local formatted
        formatted=$(format_commit_for_changelog "$subject" "$hash")

        groups["${category}"]="${groups[${category}]}${formatted}"$'\n'
    done <<< "$commits"

    # Output grouped commits
    for category in breaking added fixed changed docs internal other; do
        if [ -n "${groups[$category]}" ]; then
            echo "===${category}==="
            echo "${groups[$category]}"
        fi
    done
}

# Validate conventional commit format
validate_conventional_commit() {
    local commit_message="$1"

    # Check basic format
    if ! is_conventional_commit "$commit_message"; then
        echo "error: commit must follow conventional commit format (type: description)"
        return 1
    fi

    local type
    type=$(parse_commit_type "$commit_message")

    # Check if type is valid
    case "$type" in
        $TYPE_FEAT|$TYPE_FIX|$TYPE_PERF|$TYPE_REFACTOR|$TYPE_DOCS|$TYPE_TEST|$TYPE_BUILD|$TYPE_CI|$TYPE_CHORE|$TYPE_STYLE|bump)
            return 0
            ;;
        *)
            echo "error: unknown commit type '${type}'"
            return 1
            ;;
    esac
}

# Export functions
export -f parse_commit_type parse_commit_scope parse_commit_breaking parse_commit_description
export -f is_conventional_commit is_breaking_change is_force_bump_commit parse_force_bump_type
export -f get_commit_bump_level get_max_bump_level
export -f has_breaking_changes has_force_bump
export -f categorize_commit format_commit_for_changelog get_breaking_change_description
export -f group_commits_by_category validate_conventional_commit
