#!/usr/bin/env bash
# git-version utility functions
# Provides logging, error handling, and common operations

# Guard against double sourcing
if declare -F log_error >/dev/null 2>&1; then
    return 0
fi

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_GRAY='\033[0;90m'
readonly COLOR_RESET='\033[0m'

# Verbosity level (0=error, 1=warn, 2=info, 3=debug)
VERBOSITY=${VERBOSITY:-2}

# Logging functions
log_error() {
    printf "${COLOR_RED}[ERROR]${COLOR_RESET} %s\n" "$*" >&2
}

log_warn() {
    if [ "$VERBOSITY" -ge 1 ]; then
        printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*" >&2
    fi
}

log_info() {
    if [ "$VERBOSITY" -ge 2 ]; then
        printf "${COLOR_GREEN}[INFO]${COLOR_RESET} %s\n" "$*"
    fi
}

log_debug() {
    if [ "$VERBOSITY" -ge 3 ]; then
        printf "${COLOR_GRAY}[DEBUG]${COLOR_RESET} %s\n" "$*"
    fi
}

log_version() {
    printf "${COLOR_BLUE}%s${COLOR_RESET}\n" "$*"
}

# Error handling
die() {
    log_error "$@"
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require a command to exist
require_command() {
    if ! command_exists "$1"; then
        die "Required command not found: $1"
    fi
}

# Validate required commands
validate_dependencies() {
    require_command git
    require_command date
}

# Get current date in UTC (YYYY.MM.DD format)
get_today_utc() {
    date -u +"%Y.%m.%d"
}

# Parse date from version string
parse_version_date() {
    local version="$1"
    # Remove 'v' prefix if present
    version="${version#v}"
    # Extract date part (before dash)
    echo "$version" | cut -d'-' -f1
}

# Parse increment from version string
parse_version_increment() {
    local version="$1"
    # Remove 'v' prefix if present
    version="${version#v}"
    # Extract increment part (after dash), default to 0
    local increment=$(echo "$version" | cut -d'-' -f2 -s)
    echo "${increment:-0}"
}

# Normalize version (ensure v prefix and consistent format)
normalize_version() {
    local version="$1"
    # Ensure v prefix
    version="${version#v}"
    version="v${version}"
    echo "$version"
}

# Check if a string is a valid version format
is_valid_version() {
    local version="$1"
    # Remove 'v' prefix for validation
    version="${version#v}"
    # Check YYYY.MM.DD or YYYY.MM.DD-N format
    [[ "$version" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[0-9]+)?$ ]]
}

# Sanitize input for safe use in filenames/commands
sanitize_input() {
    local input="$1"
    # Remove null bytes and control characters
    echo "$input" | tr -d '\000-\037'
}

# Create directory with error handling
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}

# Write file with error handling
write_file() {
    local file="$1"
    local content="$2"
    local dir
    dir=$(dirname "$file")
    ensure_dir "$dir"
    echo "$content" > "$file" || die "Failed to write file: $file"
}

# Append to file with error handling
append_file() {
    local file="$1"
    local content="$2"
    echo "$content" >> "$file" || die "Failed to append to file: $file"
}

# Read file safely
read_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cat "$file"
    else
        return 1
    fi
}

# Check if file exists and is readable
file_readable() {
    [ -f "$1" ] && [ -r "$1" ]
}

# Get absolute path
get_absolute_path() {
    local path="$1"
    if [ -d "$path" ]; then
        (cd "$path" && pwd)
    elif [ -f "$path" ]; then
        local dir
        dir=$(dirname "$path")
        local base
        base=$(basename "$path")
        (cd "$dir" && echo "$(pwd)/$base")
    else
        echo "$path"
    fi
}

# Get script directory
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

# Source a library file safely
source_lib() {
    local lib_name="$1"
    local lib_dir
    lib_dir="$(get_script_dir)"
    local lib_path="${lib_dir}/${lib_name}"

    if [ -f "$lib_path" ]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    else
        die "Required library not found: ${lib_name}"
    fi
}

# Check if running in a git repository
is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Get git root directory
get_git_root() {
    if is_git_repo; then
        git rev-parse --show-toplevel
    else
        return 1
    fi
}

# Check if git HEAD is detached
is_detached_head() {
    if is_git_repo; then
        local symbolic_ref
        symbolic_ref=$(git symbolic-ref -q HEAD)
        [ -z "$symbolic_ref" ]
    else
        return 1
    fi
}

# Trim whitespace from string
trim_string() {
    local str="$1"
    # Remove leading and trailing whitespace
    echo "$str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Join array with delimiter
join_array() {
    local delimiter="$1"
    shift
    local first="$1"
    shift
    printf "%s" "$first"
    printf "%s" "${@/#/$delimiter}"
}

# Count lines in string
count_lines() {
    local str="$1"
    echo "$str" | grep -c .
}

# Check if string is empty or whitespace only
is_blank() {
    [ -z "$(trim_string "$1")" ]
}

# Export functions for use in subshells
export -f log_error log_warn log_info log_debug log_version
export -f die command_exists require_command validate_dependencies
export -f get_today_utc parse_version_date parse_version_increment normalize_version is_valid_version
export -f sanitize_input ensure_dir write_file append_file read_file file_readable
export -f get_absolute_path get_script_dir source_lib
export -f is_git_repo get_git_root is_detached_head
export -f trim_string join_array count_lines is_blank
