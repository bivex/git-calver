#!/usr/bin/env bash
# git-version changelog generation
# Generates and maintains CHANGELOG.md

# Guard against double sourcing
if declare -F update_changelog >/dev/null 2>&1; then
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

# Changelog sections
readonly SECTION_BREAKING="Breaking Changes"
readonly SECTION_ADDED="Added"
readonly SECTION_FIXED="Fixed"
readonly SECTION_CHANGED="Changed"
readonly SECTION_DEPS="Dependencies"
readonly SECTION_INTERNAL="Internal"

# Initialize changelog
init_changelog() {
    if [ ! -f "$CHANGELOG_FILE" ]; then
        write_file "$CHANGELOG_FILE" $'# Changelog\n\nAll notable changes to this project will be documented in this file.\n'
        log_info "Created ${CHANGELOG_FILE}"
    fi
}

# Get changelog template content
get_changelog_template() {
    if [ -n "$CHANGELOG_TEMPLATE" ] && [ -f "$CHANGELOG_TEMPLATE" ]; then
        cat "$CHANGELOG_TEMPLATE"
    else
        # Default template
        cat << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Calendar Versioning](https://calver.org/).

## [{{VERSION}}] - {{DATE}}

### {{SECTION}}

{{COMMITS}}

EOF
    fi
}

# Format date for changelog
get_changelog_date() {
    date -u +"%Y-%m-%d"
}

# Format version for changelog header
format_version_header() {
    local version="$1"
    local date
    date=$(get_changelog_date)
    echo "## [${version}] - ${date}"
}

# Get section title for commit category
get_section_title() {
    local category="$1"
    case "$category" in
        breaking) echo "$SECTION_BREAKING" ;;
        added) echo "$SECTION_ADDED" ;;
        fixed) echo "$SECTION_FIXED" ;;
        changed) echo "$SECTION_CHANGED" ;;
        internal) echo "$SECTION_INTERNAL" ;;
        deps) echo "$SECTION_DEPS" ;;
        *) echo "Other" ;;
    esac
}

# Format a single commit for changelog
format_changelog_entry() {
    local subject="$1"
    local commit_hash="$2"
    local scope
    scope=$(parse_commit_scope "$subject")
    local description
    description=$(parse_commit_description "$subject")

    # Add scope if present
    local entry=""
    if [ -n "$scope" ]; then
        entry="**${scope}**: ${description}"
    else
        entry="${description}"
    fi

    # Add commit hash reference
    local short_hash
    short_hash=$(echo "$commit_hash" | cut -c1-7)
    entry="${entry} ([${short_hash}])"

    echo "$entry"
}

# Generate changelog content for a version
generate_changelog_for_version() {
    local from_version="$1"
    local to_version="$2"

    local commits
    commits=$(get_commits_since "$from_version")

    if [ -z "$commits" ]; then
        log_info "No commits found for changelog"
        return
    fi

    # Group commits by category
    declare -A sections
    local breaking_section=""
    local added_section=""
    local fixed_section=""
    local changed_section=""
    local internal_section=""

    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue

        local category
        category=$(categorize_commit "$subject" "$hash")
        local entry
        entry=$(format_changelog_entry "$subject" "$hash")

        case "$category" in
            breaking)
                local breaking_desc
                breaking_desc=$(get_breaking_change_description "$hash")
                breaking_section="${breaking_section}- ${breaking_desc}"$'\n'
                ;;
            added)
                added_section="${added_section}- ${entry}"$'\n'
                ;;
            fixed)
                fixed_section="${fixed_section}- ${entry}"$'\n'
                ;;
            changed)
                changed_section="${changed_section}- ${entry}"$'\n'
                ;;
            internal)
                internal_section="${internal_section}- ${entry}"$'\n'
                ;;
        esac
    done <<< "$commits"

    # Build changelog content
    local content=""
    content="${content}$(format_version_header "$to_version")"$'\n\n'

    if [ -n "$breaking_section" ]; then
        content="${content}### ${SECTION_BREAKING}"$'\n\n'
        content="${content}${breaking_section}"$'\n'
    fi

    if [ -n "$added_section" ]; then
        content="${content}### ${SECTION_ADDED}"$'\n\n'
        content="${content}${added_section}"$'\n'
    fi

    if [ -n "$fixed_section" ]; then
        content="${content}### ${SECTION_FIXED}"$'\n\n'
        content="${content}${fixed_section}"$'\n'
    fi

    if [ -n "$changed_section" ]; then
        content="${content}### ${SECTION_CHANGED}"$'\n\n'
        content="${content}${changed_section}"$'\n'
    fi

    if [ -n "$internal_section" ]; then
        content="${content}### ${SECTION_INTERNAL}"$'\n\n'
        content="${content}${internal_section}"$'\n'
    fi

    echo "$content"
}

# Update changelog with new version
update_changelog() {
    local from_version="$1"
    local to_version="$2"

    log_info "Updating ${CHANGELOG_FILE}..."

    # Generate new changelog entry
    local new_entry
    new_entry=$(generate_changelog_for_version "$from_version" "$to_version")

    if [ -z "$new_entry" ]; then
        log_warn "No changelog entry generated"
        return
    fi

    # Check if changelog exists
    if [ ! -f "$CHANGELOG_FILE" ]; then
        init_changelog
    fi

    # Read existing changelog
    local existing_content
    existing_content=$(cat "$CHANGELOG_FILE")

    # Find insertion point (after header, before first entry)
    local new_content=""
    local header_end=false

    # Preserve header
    echo "$existing_content" | while IFS= read -r line; do
        if [ "$header_end" = false ]; then
            new_content="${new_content}${line}"$'\n'
            # Check if we've reached the end of the header
            if [[ "$line" =~ ^##\s+\[ ]]; then
                header_end=true
                new_content="${new_content}"$'\n'
            fi
        fi
    done

    # If no existing entries, append after header
    if ! echo "$existing_content" | grep -q "^##\s+\["; then
        new_content="${existing_content}"$'\n\n'
    fi

    # Insert new entry
    if echo "$existing_content" | grep -q "^##\s+\["; then
        # Insert new entry at the top
        local first_line_num
        first_line_num=$(grep -n "^##\s+\[" "$CHANGELOG_FILE" | head -1 | cut -d: -f1)

        # Use awk to insert before first entry
        awk -v entry="$new_entry" -v line_num="$first_line_num" 'NR == line_num {print entry} {print}' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"
        mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
    else
        # No existing entries, just append
        echo "$new_entry" >> "$CHANGELOG_FILE"
    fi

    log_info "Changelog updated"
}

# Generate changelog for a date range
generate_changelog_since() {
    local since_date="${1:-}"
    local version="${2:-}"

    if [ -z "$version" ]; then
        version=$(get_current_version)
    fi

    if [ -z "$since_date" ]; then
        # Use last version tag
        local last_version
        last_version=$(get_last_version)
        if [ -z "$last_version" ]; then
            since_date="1970.01.01"
        else
            since_date=$(parse_version_date "$last_version")
        fi
    fi

    log_info "Generating changelog since ${since_date}..."

    local commits
    commits=$(git log --since="${since_date}" --pretty=format:"%H|%s|%an|%ai")

    if [ -z "$commits" ]; then
        log_info "No commits found since ${since_date}"
        return
    fi

    # Generate and display changelog
    local content
    content=$(generate_changelog_for_version "v${since_date}" "$version")
    echo "$content"
}

# Display changelog for a specific version
show_version_changelog() {
    local version="$1"

    if [ ! -f "$CHANGELOG_FILE" ]; then
        log_warn "Changelog not found"
        return 1
    fi

    # Extract version section from changelog
    awk "/^##\s+\[${version}\]/,/^##\s+\[/" "$CHANGELOG_FILE" | head -n -1
}

# Validate changelog format
validate_changelog() {
    if [ ! -f "$CHANGELOG_FILE" ]; then
        log_error "Changelog not found: ${CHANGELOG_FILE}"
        return 1
    fi

    # Check for proper heading
    if ! grep -q "^# Changelog" "$CHANGELOG_FILE"; then
        log_warn "Changelog missing main heading"
    fi

    # Check for version entries
    if ! grep -q "^##\s+\[v" "$CHANGELOG_FILE"; then
        log_warn "No version entries found in changelog"
    fi

    return 0
}

# Get unreleased changes (changes not yet in a version)
get_unreleased_changes() {
    local last_version
    last_version=$(get_last_version)

    if [ -z "$last_version" ]; then
        log_info "No version tags found. Showing all commits."
        get_commits_since ""
    else
        get_commits_since "$last_version"
    fi
}

# Format unreleased section for changelog
format_unreleased_section() {
    local commits
    commits=$(get_unreleased_changes)

    if [ -z "$commits" ]; then
        return
    fi

    echo "## [Unreleased]"
    echo ""

    # Group by category
    while IFS='|' read -r hash subject author date; do
        [ -z "$hash" ] && continue

        local category
        category=$(categorize_commit "$subject" "$hash")
        local entry
        entry=$(format_changelog_entry "$subject" "$hash")
        echo "- ${entry}"
    done <<< "$commits"
}

# Export functions
export -f init_changelog get_changelog_template get_changelog_date format_version_header
export -f get_section_title format_changelog_entry generate_changelog_for_version
export -f update_changelog generate_changelog_since show_version_changelog validate_changelog
export -f get_unreleased_changes format_unreleased_section
