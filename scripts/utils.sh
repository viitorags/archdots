#!/usr/bin/env bash

# Colors and formatting
export RED='\e[31m'
export GREEN='\e[32m'
export YELLOW='\e[33m'
export BLUE='\e[34m'
export RESET='\e[0m'
export BOLD='\e[1m'

# Logging helpers
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
    exit 1
}

log_error_no_exit() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

log_section() {
    local title="$1"
    local len=${#title}
    local border=""
    for ((i=0; i<len+4; i++)); do
        border="${border}="
    done
    echo
    echo -e "${BOLD}${BLUE}${border}${RESET}"
    echo -e "${BOLD}${BLUE}  ${title}  ${RESET}"
    echo -e "${BOLD}${BLUE}${border}${RESET}"
    echo
}

# Keep sudo credentials alive in the background
sudo_keepalive() {
    # Ask for sudo password up front
    log_info "Requesting sudo permissions (needed for installation)..."
    sudo -v || log_error "Failed to acquire sudo privileges."
    
    # Keep-alive loop: update existing sudo timestamp every 60 seconds
    # Runs in the background and terminates when the parent process exits ($$)
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

# Interactive confirmation prompt
ask_confirm() {
    local prompt="$1"
    local default="${2:-y}" # y or n
    
    if [ "${RUN_NON_INTERACTIVE:-false}" = "true" ]; then
        if [[ "$default" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi

    local choice
    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="${BOLD}$prompt [Y/n]: ${RESET}"
    else
        prompt="${BOLD}$prompt [y/N]: ${RESET}"
    fi

    while true; do
        read -p "$(echo -e "$prompt")" -r choice
        if [ -z "$choice" ]; then
            choice="$default"
        fi
        case "$choice" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}
