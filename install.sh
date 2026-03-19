#!/usr/bin/env bash
# git-version installation script
# Installs git-version to ~/.local/bin or /usr/local/bin

set -euo pipefail

# Colors
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_RESET='\033[0m'

# Installation directories
INSTALL_DIR="${INSTALL_DIR:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="git-version"

# Detect installation directory
detect_install_dir() {
    if [ -n "$INSTALL_DIR" ]; then
        return
    fi

    # Prefer ~/.local/bin if it exists or can be created
    if mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        INSTALL_DIR="$HOME/.local/bin"
    elif [ -w "/usr/local/bin" ]; then
        INSTALL_DIR="/usr/local/bin"
    else
        echo -e "${COLOR_RED}Error: Cannot determine installation directory${COLOR_RESET}"
        echo "Please set INSTALL_DIR environment variable"
        exit 1
    fi
}

# Check if directory is in PATH
check_path() {
    local dir="$1"
    [[ ":$PATH:" == *":$dir:"* ]]
}

# Install the script
install_script() {
    local src="${PROJECT_ROOT}/bin/${SCRIPT_NAME}"
    local dst="${INSTALL_DIR}/${SCRIPT_NAME}"

    echo "Installing ${SCRIPT_NAME} to ${INSTALL_DIR}..."

    # Copy script
    cp "$src" "$dst"
    chmod +x "$dst"

    echo -e "${COLOR_GREEN}Installation complete!${COLOR_RESET}"
    echo ""
    echo "Installed to: ${dst}"

    # Check if in PATH
    if ! check_path "$INSTALL_DIR"; then
        echo ""
        echo -e "${COLOR_YELLOW}WARNING: ${INSTALL_DIR} is not in your PATH${COLOR_RESET}"
        echo ""
        echo "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
        echo "Then restart your shell or run:"
        echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
}

# Copy library files
install_lib_files() {
    local lib_dir="${PROJECT_ROOT}/lib"
    local target_dir="${INSTALL_DIR}/../lib"

    # Create target directory
    mkdir -p "$target_dir"

    # Copy library files
    for lib_file in "${lib_dir}"/*.sh; do
        local base_name
        base_name=$(basename "$lib_file")
        cp "$lib_file" "${target_dir}/${base_name}"
    done

    # Copy templates directory
    if [ -d "${PROJECT_ROOT}/templates" ]; then
        cp -r "${PROJECT_ROOT}/templates" "${INSTALL_DIR}/../"
    fi

    # Copy hooks directory
    if [ -d "${PROJECT_ROOT}/hooks" ]; then
        mkdir -p "${INSTALL_DIR}/../share/git-version"
        cp -r "${PROJECT_ROOT}/hooks" "${INSTALL_DIR}/../share/git-version/"
    fi
}

# Create config directory
create_config_dir() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/git-version"
    mkdir -p "$config_dir"

    # Copy default config if it doesn't exist
    if [ ! -f "${config_dir}/config.conf" ]; then
        cp "${PROJECT_ROOT}/config/git-version.conf" "${config_dir}/config.conf"
    fi
}

# Uninstall
uninstall() {
    detect_install_dir

    local dst="${INSTALL_DIR}/${SCRIPT_NAME}"

    if [ -f "$dst" ]; then
        echo "Removing ${dst}..."
        rm -f "$dst"
        echo -e "${COLOR_GREEN}Uninstallation complete${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}git-version is not installed${COLOR_RESET}"
    fi

    # Remove lib files
    local lib_dir="${INSTALL_DIR}/../lib"
    if [ -d "$lib_dir" ]; then
        echo "Removing ${lib_dir}..."
        rm -rf "$lib_dir"
    fi

    # Remove templates directory
    local templates_dir="${INSTALL_DIR}/../templates"
    if [ -d "$templates_dir" ]; then
        echo "Removing ${templates_dir}..."
        rm -rf "$templates_dir"
    fi

    # Remove share directory
    local share_dir="${INSTALL_DIR}/../share/git-version"
    if [ -d "$share_dir" ]; then
        echo "Removing ${share_dir}..."
        rm -rf "$share_dir"
    fi
}

# Show usage
show_usage() {
    cat << EOF
git-version installation script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    --uninstall    Uninstall git-version
    --help         Show this help message

ENVIRONMENT:
    INSTALL_DIR    Installation directory (default: ~/.local/bin or /usr/local/bin)

EXAMPLES:
    ./install.sh              # Install to default location
    INSTALL_DIR=/usr/local/bin ./install.sh  # Install to specific directory
    ./install.sh --uninstall  # Uninstall

EOF
}

# Main
main() {
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --uninstall)
                uninstall
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $arg"
                show_usage
                exit 1
                ;;
        esac
    done

    detect_install_dir

    # Check if running as root for /usr/local/bin
    if [ "$INSTALL_DIR" = "/usr/local/bin" ] && [ "$EUID" -ne 0 ]; then
        echo -e "${COLOR_YELLOW}Installing to /usr/local/bin requires sudo${COLOR_RESET}"
        echo "Please run: sudo ./install.sh"
        exit 1
    fi

    # Create directories
    mkdir -p "$INSTALL_DIR"

    # Install
    install_script
    install_lib_files
    create_config_dir
}

main "$@"
