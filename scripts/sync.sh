#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Get the script and repository directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared utilities
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
	source "$SCRIPT_DIR/utils.sh"
else
	echo -e "\e[31m[ERROR]\e[0m utils.sh not found."
	exit 1
fi

# Variables
DIRECTION=""
DRY_RUN=false
INTERACTIVE=true
DELETE_EXTRA=true

show_help() {
	echo "Usage: $0 [options] [direction]"
	echo "Directions:"
	echo "  to-repo        Sync configurations from the system (~/) to the repository ($REPO_DIR)"
	echo "  to-system      Sync configurations from the repository ($REPO_DIR) to the system (~/)"
	echo "Options:"
	echo "  -d, --dry-run  Show what would be transferred without making changes (rsync dry-run)"
	echo "  -n, --no-delete Do not delete files in the destination that do not exist in the source"
	echo "  -y, --yes      Run non-interactively (bypass confirmation prompts)"
	echo "  -h, --help     Show this help message"
}

# Parse options
while [[ $# -gt 0 ]]; do
	case $1 in
	to-repo | to-system)
		DIRECTION="$1"
		shift
		;;
	-d | --dry-run)
		DRY_RUN=true
		shift
		;;
	-n | --no-delete)
		DELETE_EXTRA=false
		shift
		;;
	-y | --yes)
		export RUN_NON_INTERACTIVE=true
		INTERACTIVE=false
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

# If direction not provided via CLI, ask interactively
if [ -z "$DIRECTION" ]; then
	if [ "${RUN_NON_INTERACTIVE:-false}" = "true" ]; then
		log_error "Direction (to-repo or to-system) must be specified in non-interactive mode."
	fi

	echo "Select synchronization direction:"
	echo "  1) [to-repo]   Sync local system config (~/) -> Repository ($REPO_DIR)"
	echo "  2) [to-system] Sync Repository ($REPO_DIR) -> local system config (~/)"
	echo "  3) Cancel"
	read -p "Enter choice [1-3]: " choice
	choice="${choice:-3}"
	case "$choice" in
	1) DIRECTION="to-repo" ;;
	2) DIRECTION="to-system" ;;
	*)
		log_info "Synchronization cancelled."
		exit 0
		;;
	esac
fi

# Exclusions list for rsync (ignoring .git, dependencies, virtual environments, caches, etc.)
RSYNC_EXCLUDES=(
	--exclude='.git/'
	--exclude='.gitattributes'
	--exclude='.gitignore'
	--exclude='node_modules/'
	--exclude='vendor/'
	--exclude='bower_components/'
	--exclude='.npm/'
	--exclude='.cache/'
	--exclude='cache/'
	--exclude='tmp/'
	--exclude='temp/'
	--exclude='obj/'
	--exclude='bin/'
	--exclude='target/'
	--exclude='dist/'
	--exclude='build/'
	--exclude='out/'
	--exclude='venv/'
	--exclude='.venv/'
	--exclude='env/'
	--exclude='.env/'
	--exclude='.env.local'
	--exclude='__pycache__/'
	--exclude='.ipynb_checkpoints/'
	--exclude='.DS_Store'
	--exclude='*.log'
	--exclude='*.tmp'
	--exclude='.bundle/'
	--exclude='vendor/bundle/'
)

# Common rsync options (-a: archive, -v: verbose, -h: human-readable)
BASE_RSYNC_OPTS=(-avh)
[ "$DRY_RUN" = "true" ] && BASE_RSYNC_OPTS+=(-n)

DIR_RSYNC_OPTS=("${BASE_RSYNC_OPTS[@]}")
[ "$DELETE_EXTRA" = "true" ] && DIR_RSYNC_OPTS+=(--delete)

# Define configs tracked in the repo config folder dynamically
CONFIG_ITEMS=()
if [ -d "$REPO_DIR/config" ]; then
	for dir in "$REPO_DIR/config"/*; do
		if [ -d "$dir" ]; then
			CONFIG_ITEMS+=("config/$(basename "$dir")")
		fi
	done
fi

# Add .zshrc if it exists in the repository
if [ -f "$REPO_DIR/.zshrc" ]; then
	CONFIG_ITEMS+=(".zshrc")
fi

# Add fonts dir if it exists in the repository
if [ -d "$REPO_DIR/fonts" ]; then
	CONFIG_ITEMS+=("fonts")
fi

# Log synchronization details
if [ "$DIRECTION" = "to-repo" ]; then
	log_section "Syncing from Local System to Repository"
	log_info "The following items will be copied to your repository ($REPO_DIR):"
else
	log_section "Syncing from Repository to Local System"
	log_info "The following items on your system will be updated:"
fi

for item in "${CONFIG_ITEMS[@]}"; do
	sys_item="$item"
	if [[ "$item" == config/* ]]; then
		sys_item=".config/${item#config/}"
	elif [[ "$item" == "fonts" ]]; then
		sys_item=".local/share/fonts"
	fi

	if [ "$DIRECTION" = "to-repo" ]; then
		echo -e "  - ${BLUE}~/$sys_item${RESET}  ->  ${GREEN}$item${RESET}"
	else
		echo -e "  - ${GREEN}$item${RESET}  ->  ${BLUE}~/$sys_item${RESET}"
	fi
done
echo

if [ "$DRY_RUN" = "true" ]; then
	log_warning "DRY RUN mode active. No files will be modified."
fi

# Ask for confirmation before modifying files (unless dry-run or --yes/non-interactive is specified)
if [ "$DRY_RUN" = "false" ] && [ "$INTERACTIVE" = "true" ]; then
	if ! ask_confirm "Are you sure you want to proceed with synchronization?" "y"; then
		log_info "Synchronization cancelled."
		exit 0
	fi
fi

# Backup existing configs before overwriting (to-system only)
if [ "$DIRECTION" = "to-system" ] && [ "$DRY_RUN" = "false" ]; then
	BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$BACKUP_DIR"
	log_info "Backing up existing configs to $BACKUP_DIR..."
	for item in "${CONFIG_ITEMS[@]}"; do
		sys_item="$item"
		if [[ "$item" == config/* ]]; then
			sys_item=".config/${item#config/}"
		elif [[ "$item" == "fonts" ]]; then
			sys_item=".local/share/fonts"
		fi
		[ -e "$HOME/$sys_item" ] && cp -r "$HOME/$sys_item" "$BACKUP_DIR/"
	done
	log_success "Backup saved to $BACKUP_DIR"
fi

# Perform the sync
for item in "${CONFIG_ITEMS[@]}"; do
	# Map repository configuration path (e.g. config/niri) to system path (e.g. .config/niri)
	sys_item="$item"
	if [[ "$item" == config/* ]]; then
		sys_item=".config/${item#config/}"
	elif [[ "$item" == "fonts" ]]; then
		sys_item=".local/share/fonts"
	fi

	if [ "$DIRECTION" = "to-repo" ]; then
		SRC="$HOME/$sys_item"
		DST="$REPO_DIR/$item"
	else
		SRC="$REPO_DIR/$item"
		DST="$HOME/$sys_item"
	fi

	# If copying from system and it does not exist, log a warning and skip
	if [ ! -e "$SRC" ]; then
		log_warning "Source does not exist: $SRC. Skipping $item..."
		continue
	fi

	# Ensure the target parent directory exists
	if [ "$DRY_RUN" = "false" ]; then
		mkdir -p "$(dirname "$DST")"
	fi

	# Handle directories vs files
	if [ -d "$SRC" ]; then
		log_info "Syncing directory: $item"
		rsync "${DIR_RSYNC_OPTS[@]}" "${RSYNC_EXCLUDES[@]}" "$SRC/" "$DST/" || log_warning "Failed to sync directory: $item"
	else
		log_info "Syncing file: $item"
		rsync "${BASE_RSYNC_OPTS[@]}" "${RSYNC_EXCLUDES[@]}" "$SRC" "$DST" || log_warning "Failed to sync file: $item"
	fi
done

if [ "$DRY_RUN" = "true" ]; then
	log_success "Dry run simulation complete!"
else
	# Rebuild font cache if fonts were synced to system
	if [ "$DIRECTION" = "to-system" ] && [[ " ${CONFIG_ITEMS[*]} " == *" fonts "* ]]; then
		log_info "Updating font cache..."
		fc-cache -f && log_success "Font cache updated."
	fi
	log_success "Synchronization completed successfully!"
fi
