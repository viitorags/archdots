#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
	source "$SCRIPT_DIR/utils.sh"
else
	echo -e "\e[31m[ERROR]\e[0m utils.sh not found."
	exit 1
fi

if [ "$EUID" -eq 0 ]; then
	log_error "Please do not run this script as root or using sudo. The script will ask for sudo when needed."
fi

# Variables
RUN_PACMAN=false
RUN_AUR=false
RUN_CUSTOM=false
HAS_FLAGS=false
export RUN_NON_INTERACTIVE=false
export DRY_RUN=false

# Help function
show_help() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -p, --pacman   Install official Arch packages (Phase 1)"
	echo "  -a, --aur      Install AUR packages via paru (Phase 2)"
	echo "  -c, --custom   Run custom installations & services (Phase 3)"
	echo "  -y, --yes      Run non-interactively (automatic yes to prompts)"
	echo "  -d, --dry-run  Dry run (show what would be done without installing)"
	echo "  -h, --help     Show this help message"
}

# Parse options
while [[ $# -gt 0 ]]; do
	case $1 in
	-p | --pacman)
		RUN_PACMAN=true
		HAS_FLAGS=true
		shift
		;;
	-a | --aur)
		RUN_AUR=true
		HAS_FLAGS=true
		shift
		;;
	-c | --custom)
		RUN_CUSTOM=true
		HAS_FLAGS=true
		shift
		;;
	-y | --yes)
		RUN_NON_INTERACTIVE=true
		shift
		;;
	-d | --dry-run)
		export DRY_RUN=true
		shift
		;;
	-h | --help)
		show_help
		exit 0
		;;
	*)
		log_error "Unknown option: $1. Use -h or --help for usage."
		;;
	esac
done

log_section "Starting Arch Linux Setup"

if [ "$DRY_RUN" = "true" ]; then
	log_info "DRY RUN MODE ACTIVE. No changes will be made to your system."
fi

# If no flags are provided, show an interactive menu
if [ "$HAS_FLAGS" = false ]; then
	if [ "$RUN_NON_INTERACTIVE" = "true" ]; then
		# In non-interactive mode with no flags, run all phases
		RUN_PACMAN=true
		RUN_AUR=true
		RUN_CUSTOM=true
	else
		echo "Select installation mode:"
		echo "  1) Full installation (All phases) [Default]"
		echo "  2) Custom selection (Choose individual phases)"
		echo "  3) Cancel"
		read -p "Enter choice [1-3]: " choice
		
		# If user pressed enter, default to 1
		choice="${choice:-1}"
		
		case "$choice" in
			1)
				RUN_PACMAN=true
				RUN_AUR=true
				RUN_CUSTOM=true
				;;
			2)
				if ask_confirm "Run Phase 1: Install official pacman packages?" "y"; then
					RUN_PACMAN=true
				fi
				if ask_confirm "Run Phase 2: Install AUR packages via paru?" "y"; then
					RUN_AUR=true
				fi
				if ask_confirm "Run Phase 3: Run custom installations & services?" "y"; then
					RUN_CUSTOM=true
				fi
				if [ "$RUN_PACMAN" = false ] && [ "$RUN_AUR" = false ] && [ "$RUN_CUSTOM" = false ]; then
					log_info "No phases selected. Exiting."
					exit 0
				fi
				;;
			*)
				log_info "Installation cancelled."
				exit 0
				;;
		esac
	fi
fi

# Keep sudo alive if we're not running in dry-run mode
if [ "$DRY_RUN" = "false" ]; then
	sudo_keepalive
fi

# Step 1: Install official pacman packages
if [ "$RUN_PACMAN" = true ]; then
	log_section "Phase 1: Official Pacman Packages"
	if [ -f "$SCRIPT_DIR/01-pacman.sh" ]; then
		bash "$SCRIPT_DIR/01-pacman.sh"
	else
		log_error "01-pacman.sh not found."
	fi
fi

# Step 2: Install AUR packages via paru
if [ "$RUN_AUR" = true ]; then
	log_section "Phase 2: AUR Packages (Paru)"
	if [ -f "$SCRIPT_DIR/02-paru.sh" ]; then
		bash "$SCRIPT_DIR/02-paru.sh"
	else
		log_error "02-paru.sh not found."
	fi
fi

# Step 3: Custom configurations, flatpaks and systemd services
if [ "$RUN_CUSTOM" = true ]; then
	log_section "Phase 3: Custom Configurations & Services"
	if [ -f "$SCRIPT_DIR/03-custom.sh" ]; then
		bash "$SCRIPT_DIR/03-custom.sh"
	else
		log_error "03-custom.sh not found."
	fi
fi

echo "=========================================================="
log_success "Setup Complete!"
log_info "Note: Remember to add '~/.config/composer/vendor/bin'"
log_info "      and '~/.bun/bin' to your PATH to use them."
echo "=========================================================="

if ask_confirm "Deploy configs from repository to system now?" "y"; then
	bash "$SCRIPT_DIR/sync.sh" to-system
fi
