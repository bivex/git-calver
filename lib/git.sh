#!/usr/bin/env bash
# git-version git operations wrapper
# Provides git-related operations for version management

# Guard against double sourcing
if declare -F get_last_version >/dev/null 2>&1; then
    return 0
fi

# Source utility functions
# shellcheck source=./lib/utils.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Get the last version from git tags
# Returns the most recent version tag or empty string if none exist
get_last_version() {
    local tags
    tags=$(git tag -l "v[0-9]*" --sort=-v:refname | head -1)
    if [ -n "$tags" ]; then
        normalize_version "$tags"
    else
        echo ""
    fi
}

# Get all version tags sorted
get_all_versions() {
    git tag -l "v[0-9]*" --sort=v:refname
}

# Get the date of the last version tag
get_last_version_date() {
    local last_version
    last_version=$(get_last_version)
    if [ -n "$last_version" ]; then
        local tag_date
        tag_date=$(git log -1 --format=%ai "${last_version}" 2>/dev/null | cut -d' ' -f1)
        # Convert to YYYY.MM.DD format
        if [ -n "$tag_date" ]; then
            echo "$tag_date" | tr '-' '.'
        fi
    fi
}

# Get commits since last version
get_commits_since() {
    local since_version="$1"
    local range
    if [ -n "$since_version" ]; then
        range="${since_version}..HEAD"
    else
        range="HEAD"
    fi
    git log "${range}" --pretty=format:"%H|%s|%an|%ai" 2>/dev/null || echo ""
}

# Get commits since last version tag
get_commits_since_last_version() {
    local last_version
    last_version=$(get_last_version)
    get_commits_since "$last_version"
}

# Get the last N commits
get_last_n_commits() {
    local count="${1:-10}"
    git log -"${count}" --pretty=format:"%H|%s|%an|%ai" 2>/dev/null || echo ""
}

# Get the current branch name
get_current_branch() {
    if is_detached_head; then
        echo "detached"
    else
        git rev-parse --abbrev-ref HEAD
    fi
}

# Get the short commit hash
get_short_hash() {
    git rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

# Get the full commit hash
get_full_hash() {
    git rev-parse HEAD 2>/dev/null || echo "unknown"
}

# Check if there are new commits since last version
has_new_commits() {
    local since_version="$1"
    local commits
    commits=$(get_commits_since "$since_version")
    [ -n "$commits" ]
}

# Create a git tag
create_tag() {
    local tag_name="$1"
    local message="${2:-Release ${tag_name}}"

    log_debug "Creating tag: ${tag_name}"
    if git tag -a "$tag_name" -m "$message" 2>/dev/null; then
        log_info "Created tag: ${tag_name}"
        return 0
    else
        log_error "Failed to create tag: ${tag_name}"
        return 1
    fi
}

# Delete a git tag
delete_tag() {
    local tag_name="$1"
    log_debug "Deleting tag: ${tag_name}"
    if git tag -d "$tag_name" 2>/dev/null; then
        log_info "Deleted tag: ${tag_name}"
        return 0
    else
        log_warn "Failed to delete tag: ${tag_name} (may not exist)"
        return 1
    fi
}

# Check if a tag exists
tag_exists() {
    local tag_name="$1"
    git rev-parse -q --verify "refs/tags/${tag_name}" >/dev/null
}

# Push tags to remote
push_tags() {
    local remote="${1:-origin}"
    log_info "Pushing tags to ${remote}..."
    if git push "${remote}" --tags 2>/dev/null; then
        log_info "Tags pushed successfully"
        return 0
    else
        log_error "Failed to push tags"
        return 1
    fi
}

# Get commit body by hash
get_commit_body() {
    local commit_hash="$1"
    git log -1 --pretty=%B "${commit_hash}" 2>/dev/null || echo ""
}

# Get commit subject by hash
get_commit_subject() {
    local commit_hash="$1"
    git log -1 --pretty=%s "${commit_hash}" 2>/dev/null || echo ""
}

# Get commits matching a pattern
get_commits_matching() {
    local pattern="$1"
    local since_version="$2"
    local range
    if [ -n "$since_version" ]; then
        range="${since_version}..HEAD"
    else
        range="HEAD"
    fi
    git log "${range}" --grep="$pattern" --pretty=format:"%H|%s|%an|%ai" 2>/dev/null || echo ""
}

# Check if commit has breaking change footer
has_breaking_change_footer() {
    local commit_hash="$1"
    local body
    body=$(get_commit_body "$commit_hash")
    echo "$body" | grep -q "BREAKING CHANGE:"
}

# Check if commit subject has breaking change (!)
has_breaking_change_subject() {
    local commit_subject="$1"
    echo "$commit_subject" | grep -q "!"
}

# Get commit author
get_commit_author() {
    local commit_hash="$1"
    git log -1 --pretty=%an "${commit_hash}" 2>/dev/null || echo "Unknown"
}

# Get commit date in UTC
get_commit_date_utc() {
    local commit_hash="$1"
    git log -1 --format=%aI "${commit_hash}" 2>/dev/null | cut -d'T' -f1 | tr '-' '.' || echo ""
}

# Check if working directory is clean
is_working_dir_clean() {
    git diff-index --quiet HEAD -- 2>/dev/null
}

# Get modified files
get_modified_files() {
    git diff --name-only HEAD 2>/dev/null || echo ""
}

# Get untracked files
get_untracked_files() {
    git ls-files --others --exclude-standard 2>/dev/null || echo ""
}

# Add files to git
git_add() {
    local files="$*"
    git add $files 2>/dev/null
}

# Commit changes
git_commit() {
    local message="$1"
    git commit -m "$message" 2>/dev/null
}

# Check if remote exists
remote_exists() {
    local remote="${1:-origin}"
    git remote get-url "$remote" >/dev/null 2>&1
}

# Get remote URL
get_remote_url() {
    local remote="${1:-origin}"
    git remote get-url "$remote" 2>/dev/null || echo ""
}

# Get repository name from remote
get_repo_name() {
    local url
    url=$(get_remote_url)
    if [ -n "$url" ]; then
        # Extract repo name from URL (handles both git@ and https://)
        echo "$url" | sed -E 's|.*/([^/]+)?\.git$|\1|'
    else
        basename "$(get_git_root)"
    fi
}

# Check if we can push to remote
can_push() {
    remote_exists && is_working_dir_clean
}

# Get total commit count
get_commit_count() {
    git rev-list --count HEAD 2>/dev/null || echo "0"
}

# Get commits by type (conventional commits)
get_commits_by_type() {
    local type="$1"
    local since_version="$2"
    local pattern="^${type}:"

    if [ "$type" = "breaking" ]; then
        # Special handling for breaking changes
        local commits
        commits=$(get_commits_since "$since_version")
        local breaking_commits=""
        while IFS='|' read -r hash subject author date; do
            if has_breaking_change_subject "$subject" || has_breaking_change_footer "$hash"; then
                breaking_commits="${breaking_commits}${hash}|${subject}|${author}|${date}"$'\n'
            fi
        done <<< "$commits"
        echo "$breaking_commits"
    else
        get_commits_matching "$pattern" "$since_version"
    fi
}

# Get all commits as structured data
get_all_commits_structured() {
    local since_version="$1"
    local commits
    commits=$(get_commits_since "$since_version")

    local result=""
    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue
        local body
        body=$(get_commit_body "$hash")
        result="${result}${hash}|${subject}|${author}|${date}|${body}"$'\n'
    done <<< "$commits"

    echo "$result"
}

# Export functions
export -f get_last_version get_all_versions get_last_version_date
export -f get_commits_since get_commits_since_last_version get_last_n_commits
export -f get_current_branch get_short_hash get_full_hash has_new_commits
export -f create_tag delete_tag tag_exists push_tags
export -f get_commit_body get_commit_subject get_commits_matching
export -f has_breaking_change_footer has_breaking_change_subject
export -f get_commit_author get_commit_date_utc
export -f is_working_dir_clean get_modified_files get_untracked_files
export -f git_add git_commit remote_exists get_remote_url get_repo_name can_push
export -f get_commit_count get_commits_by_type get_all_commits_structured
