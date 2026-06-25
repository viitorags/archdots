#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# Note: we don't set -e immediately so we can handle check/installation of paru manually
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
	source "$SCRIPT_DIR/utils.sh"
else
	echo -e "\e[31m[ERROR]\e[0m utils.sh not found."
	exit 1
fi

DRY_RUN="${DRY_RUN:-false}"

log_section "AUR (Paru) Packages Phase"

# Initialize Rust toolchain (required for building paru from source)
if command -v rustup &>/dev/null; then
	log_info "Checking Rust toolchain (required for building paru from source)..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would ensure rustup toolchain is initialized: rustup default stable"
	else
		if ! rustup show active-toolchain &>/dev/null; then
			log_info "Initializing rustup stable toolchain..."
			rustup default stable || log_warning "Failed to initialize rustup stable toolchain."
		else
			log_success "Rust toolchain is already active."
		fi
	fi
	# Update PATH for the cargo/rustc binaries to be accessible by makepkg
	export PATH="$HOME/.cargo/bin:$PATH"
	log_info "PATH updated with Rust cargo binaries: $HOME/.cargo/bin"
else
	log_warning "rustup is not installed. Paru compilation might fail if rustc/cargo are missing."
fi

# Ensure base-devel and git are installed (needed to build AUR packages)
log_info "Ensuring base-devel and git are installed..."
if [ "$DRY_RUN" = "true" ]; then
	log_info "[DRY RUN] Would run: sudo pacman -S --needed --noconfirm base-devel git"
else
	sudo pacman -S --needed --noconfirm base-devel git
fi

# Check if paru is installed, if not bootstrap it
if ! command -v paru &>/dev/null; then
	log_info "Paru is not installed. Bootstrapping paru from AUR (compiling from source)..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would clone https://aur.archlinux.org/paru.git and run makepkg -si --noconfirm"
	else
		TEMP_DIR=$(mktemp -d)

		# Clone and build paru (from source, compiling Rust code)
		git clone https://aur.archlinux.org/paru.git "$TEMP_DIR"

		# Run makepkg as the current non-root user
		(
			cd "$TEMP_DIR"
			makepkg -si --noconfirm
		)

		# Clean up
		rm -rf "$TEMP_DIR"
		log_success "Paru successfully installed!"
	fi
else
	log_info "Paru is already installed. Proceeding..."
fi

# Set -e for the package installation phase to halt on failures (except we handle individual fallback)
set -e

# Categorized AUR packages matching the NixOS configuration
AUR_PACKAGES=(
	# System & Desktop Apps (from desktopPackages / home.nix)
	# brave-bin
	zen-browser-bin
	xwayland-satellite-git
	gpu-screen-recorder
	#labymod-launcher
	# sonobus-bin
	# mpvpaper-git
	localsend-bin
	#pokemon-colorscripts-git
	waydroid
	proton-vpn-gtk-app
	#xcursor-vimix
	#sddm-astronaut-theme-git
	noctalia-git

	# Fonts (from fonts.packages in packages.nix)
	# ttf-victor-mono-nerd
	ttf-jetbrains-mono-nerd
	ttf-material-symbols-variable-git
	# ttf-sarasa-gothic

	# Dev Tools & Shells (from dev/default.nix)
	# flyctl-bin
	# godot-mono-bin
	# visual-studio-code-bin # Matches vscode-fhs
	# bun-bin
	# insomnia-bin
	# lazydocker-bin
	# quickshell-git
	# alejandra-bin
	# statix-bin
	# deadnix-bin
	#ripdrag-bin
)

install_aur_packages_with_fallback() {
	local pkgs=("${@}")
	log_info "Installing AUR packages via paru..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would run: paru -S --needed --noconfirm ${pkgs[*]}"
		return 0
	fi

	if ! paru -S --needed --noconfirm "${pkgs[@]}"; then
		log_warning "Failed to install some AUR packages in bulk. Attempting to install individually to isolate errors..."
		local failed_pkgs=()
		for pkg in "${pkgs[@]}"; do
			if ! paru -S --needed --noconfirm "$pkg"; then
				log_error_no_exit "Failed to install AUR package: $pkg"
				failed_pkgs+=("$pkg")
			fi
		done
		if [ ${#failed_pkgs[@]} -ne 0 ]; then
			log_warning "The following AUR packages could not be installed: ${failed_pkgs[*]}"
		else
			log_success "All AUR packages installed after individual retry!"
		fi
	else
		log_success "AUR packages installation completed."
	fi
}

install_aur_packages_with_fallback "${AUR_PACKAGES[@]}"

log_success "AUR packages installation process completed!"
