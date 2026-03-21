#!/usr/bin/env bash
# git-version core version calculation
# Implements calendar-based versioning with daily increments

# Guard against double sourcing
if declare -F calculate_next_version >/dev/null 2>&1; then
    return 0
fi

# Source utility functions
# shellcheck source=./lib/utils.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Source git functions
# shellcheck source=./lib/git.sh
source "${SCRIPT_DIR}/git.sh"

# Source conventional commits parser
# shellcheck source=./lib/conventional.sh
source "${SCRIPT_DIR}/conventional.sh"

# Default configuration
VERSION_FILE="${VERSION_FILE:-VERSION.txt}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
CHANGELOG_TEMPLATE="${CHANGELOG_TEMPLATE:-}"

# Initialize versioning in a new repository
init_versioning() {
    log_info "Initializing git-version..."

    local today
    today=$(get_today_utc)
    local initial_version="v${today}"

    # Create VERSION.txt if it doesn't exist
    if [ ! -f "$VERSION_FILE" ]; then
        write_file "$VERSION_FILE" "$initial_version"
        log_info "Created ${VERSION_FILE} with version: ${initial_version}"
    else
        log_info "${VERSION_FILE} already exists"
    fi

    # Create CHANGELOG.md if it doesn't exist
    if [ ! -f "$CHANGELOG_FILE" ]; then
        write_file "$CHANGELOG_FILE" $'# Changelog\n\nAll notable changes to this project will be documented in this file.\n'
        log_info "Created ${CHANGELOG_FILE}"
    else
        log_info "${CHANGELOG_FILE} already exists"
    fi

    # Create initial tag if no tags exist
    if [ -z "$(get_last_version)" ]; then
        create_tag "$initial_version" "Initial version"
    else
        log_info "Git tags already exist"
    fi

    log_info "Initialization complete"
}

# Calculate the next version based on git history
calculate_next_version() {
    local force_bump_type="$1"
    local last_version
    last_version=$(get_last_version)

    local today
    today=$(get_today_utc)

    # If no version exists, start with today
    if [ -z "$last_version" ]; then
        echo "v${today}"
        return
    fi

    # Parse last version
    local last_date
    last_date=$(parse_version_date "$last_version")
    local last_increment
    last_increment=$(parse_version_increment "$last_version")

    # Check for force bump or breaking changes
    local commits
    commits=$(get_commits_since_last_version)

    # If no new commits, return current version
    if [ -z "$commits" ] && [ -z "$force_bump_type" ]; then
        echo "$last_version"
        return
    fi

    local should_bump=false

    # Check for force bump
    if [ -n "$force_bump_type" ]; then
        should_bump=true
    elif has_force_bump "$commits"; then
        should_bump=true
    elif has_breaking_changes "$commits"; then
        should_bump=true
    fi

    # Calculate new version
    if [ "$should_bump" = true ]; then
        if [ "$today" = "$last_date" ]; then
            # Same day, increment
            local new_increment=$((last_increment + 1))
            echo "v${today}-${new_increment}"
        else
            # New day, reset increment
            echo "v${today}"
        fi
    else
        # No breaking changes, but there are commits - still bump
        if [ "$today" = "$last_date" ]; then
            local new_increment=$((last_increment + 1))
            echo "v${today}-${new_increment}"
        else
            echo "v${today}"
        fi
    fi
}

# Calculate next version without applying it
show_next_version() {
    local force_bump_type="$1"
    local next_version
    next_version=$(calculate_next_version "$force_bump_type")

    local last_version
    last_version=$(get_last_version)

    log_version "$next_version"

    if [ -n "$last_version" ]; then
        log_info "Previous version: ${last_version}"
    fi

    # Show what would cause the bump
    local commits
    commits=$(get_commits_since_last_version)
    if [ -n "$commits" ]; then
        log_info "Commits since last version:"
        echo "$commits" | while IFS='|' read -r hash subject author date; do
            [ -z "$hash" ] && continue
            echo "  - ${subject}"
        done
    fi
}

# Apply version bump
apply_version_bump() {
    local force_bump_type="$1"
    local skip_tag="${2:-false}"

    local next_version
    next_version=$(calculate_next_version "$force_bump_type")

    local last_version
    last_version=$(get_last_version)

    # Check if version actually changed
    if [ "$next_version" = "$last_version" ] && [ -z "$force_bump_type" ]; then
        log_info "No changes to version: ${next_version}"
        return 0
    fi

    log_info "Bumping version: ${last_version:-none} → ${next_version}"

    # Update VERSION.txt
    write_file "$VERSION_FILE" "$next_version"
    log_info "Updated ${VERSION_FILE}"

    # Update CHANGELOG.md
    update_changelog "$last_version" "$next_version"

    # Stage VERSION.txt and CHANGELOG.md for the next release commit
    git_add "$VERSION_FILE" "$CHANGELOG_FILE"
    log_info "Staged ${VERSION_FILE} and ${CHANGELOG_FILE}"

    # Create git tag
    if [ "$skip_tag" != "true" ]; then
        create_tag "$next_version" "Release ${next_version}"

        log_info "Version bump complete: ${next_version}"
        log_info "Files staged. Commit with: git commit -m 'chore: release ${next_version}'"
    else
        log_info "Version bump complete (tag skipped): ${next_version}"
    fi

    return 0
}

# Get current version from VERSION.txt or git tags
get_current_version() {
    # First check VERSION.txt
    if [ -f "$VERSION_FILE" ]; then
        local version
        version=$(cat "$VERSION_FILE" 2>/dev/null)
        if is_valid_version "$version"; then
            normalize_version "$version"
            return
        fi
    fi

    # Fall back to git tags
    local last_version
    last_version=$(get_last_version)
    if [ -n "$last_version" ]; then
        echo "$last_version"
        return
    fi

    # No version found
    log_warn "No version found. Run 'git-version init' to initialize."
    return 1
}

# Compare two versions
# Returns: 0 if equal, 1 if first > second, 2 if second > first
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Normalize versions
    v1=$(normalize_version "$v1")
    v2=$(normalize_version "$v2")

    # Remove 'v' prefix
    v1="${v1#v}"
    v2="${v2#v}"

    # Split into date and increment
    local v1_date v1_inc v2_date v2_inc
    v1_date=$(echo "$v1" | cut -d'-' -f1)
    v1_inc=$(echo "$v1" | cut -d'-' -f2 -s)
    v2_date=$(echo "$v2" | cut -d'-' -f1)
    v2_inc=$(echo "$v2" | cut -d'-' -f2 -s)

    # Default increment to 0
    v1_inc="${v1_inc:-0}"
    v2_inc="${v2_inc:-0}"

    # Compare dates (string comparison works for YYYY.MM.DD)
    if [ "$v1_date" \> "$v2_date" ]; then
        return 1
    elif [ "$v1_date" \< "$v2_date" ]; then
        return 2
    fi

    # Same date, compare increments
    if [ "$v1_inc" -gt "$v2_inc" ]; then
        return 1
    elif [ "$v1_inc" -lt "$v2_inc" ]; then
        return 2
    fi

    # Equal
    return 0
}

# Validate version format
validate_version() {
    local version="$1"
    if ! is_valid_version "$version"; then
        log_error "Invalid version format: ${version}"
        log_error "Expected format: YYYY.MM.DD or YYYY.MM.DD-N"
        return 1
    fi
    return 0
}

# Resolve version conflicts (for merge conflicts in VERSION.txt)
resolve_version_conflict() {
    log_warn "Attempting to resolve version conflict..."

    local calculated
    calculated=$(calculate_next_version)

    write_file "$VERSION_FILE" "$calculated"
    log_info "Resolved to: ${calculated}"

    git_add "$VERSION_FILE"
}

# Get version for a specific commit
get_version_for_commit() {
    local commit_hash="$1"
    local tags
    tags=$(git tag --contains "$commit_hash" -l "v[0-9]*" --sort=v:refname)

    if [ -n "$tags" ]; then
        # Return the last tag that includes this commit
        echo "$tags" | tail -1
    else
        # Return the version before this commit
        local before_tags
        before_tags=$(git tag -l "v[0-9]*" --sort=-v:refname | head -1)
        echo "$before_tags"
    fi
}

# Get all versions between two commits
get_versions_between() {
    local start_commit="$1"
    local end_commit="${2:-HEAD}"

    git log "${start_commit}..${end_commit}" --pretty=format:"%H" | while read -r hash; do
        get_version_for_commit "$hash"
    done | sort -u | grep -v "^$"
}

# Export functions
export -f init_versioning calculate_next_version show_next_version apply_version_bump
export -f get_current_version compare_versions validate_version resolve_version_conflict
export -f get_version_for_commit get_versions_between
