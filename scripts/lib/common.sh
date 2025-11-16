#!/bin/bash
# Common utilities for Local-LLM-Kit scripts
# Provides: logging, colors, OS detection, browser opening

# Color codes (only if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Logging functions
log_info() {
    echo -e "  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_header() {
    echo -e "\n${BOLD}$1${NC}"
}

# Detect operating system
# Returns: linux, macos, or wsl
detect_os() {
    case "$OSTYPE" in
        linux-gnu*)
            # Check if running under WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if a command is available
# Usage: is_command_available "docker"
is_command_available() {
    command -v "$1" &> /dev/null
}

# Open browser cross-platform
# Usage: open_browser "http://localhost:11300"
open_browser() {
    local url="$1"
    local OS=$(detect_os)

    case "$OS" in
        linux)
            if is_command_available xdg-open; then
                xdg-open "$url" &>/dev/null &
                return 0
            fi
            ;;
        macos)
            if is_command_available open; then
                open "$url" &>/dev/null &
                return 0
            fi
            ;;
        wsl)
            # Try WSL-specific commands first
            if is_command_available wslview; then
                wslview "$url" &>/dev/null &
                return 0
            elif is_command_available cmd.exe; then
                cmd.exe /c start "$url" &>/dev/null &
                return 0
            fi
            ;;
    esac

    # If we got here, browser opening failed
    return 1
}

# Confirm action with yes/no prompt
# Usage: if confirm_yes_no "Are you sure?"; then ... fi
# Returns: 0 for yes, 1 for no
confirm_yes_no() {
    local prompt="$1"
    local default="${2:-n}"  # Default to 'n' if not specified

    if [ "$default" = "y" ]; then
        local prompt_suffix="[Y/n]"
    else
        local prompt_suffix="[y/N]"
    fi

    read -p "$prompt $prompt_suffix " -n 1 -r
    echo  # New line after input

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        return 1
    else
        # User just pressed enter, use default
        if [ "$default" = "y" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Check if script is being run with sudo (warn if so)
check_not_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run this script with sudo!"
        log_info "Docker commands should work without sudo if you're in the docker group"
        log_info "Add yourself: sudo usermod -aG docker \$USER"
        exit 1
    fi
}

# Wait with spinner
# Usage: wait_with_spinner 5 "Waiting for service"
wait_with_spinner() {
    local duration="$1"
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    echo -n "$message "
    while [ $i -lt $duration ]; do
        i=$(( (i+1) ))
        printf "\b${spin:i%${#spin}:1}"
        sleep 1
    done
    printf "\b✓\n"
}
