#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# Note: we don't set -e immediately so we can handle check/installation of paru manually
set -uo pipefail

# Helper functions for logging
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
log_error() {
	echo -e "\e[31m[ERROR]\e[0m $1"
	exit 1
}

echo "========================================="
echo "  Installing Arch Linux AUR (Paru) Packages "
echo "========================================="

# Ensure base-devel and git are installed (needed to build AUR packages)
log_info "Ensuring base-devel and git are installed..."
sudo pacman -S --needed --noconfirm base-devel git

# Check if paru is installed, if not bootstrap it
if ! command -v paru &>/dev/null; then
	log_info "Paru is not installed. Bootstrapping paru-bin from AUR..."
	TEMP_DIR=$(mktemp -d)

	# Clone and build paru-bin (faster than compiling paru from source)
	git clone https://aur.archlinux.org/paru-bin.git "$TEMP_DIR"

	# Run makepkg as the current non-root user
	(
		cd "$TEMP_DIR"
		makepkg -si --noconfirm
	)

	# Clean up
	rm -rf "$TEMP_DIR"
	log_success "Paru successfully installed!"
else
	log_info "Paru is already installed. Proceeding..."
fi

# Set -e for the package installation phase to halt on failures
set -e

# Categorized AUR packages matching the NixOS configuration
AUR_PACKAGES=(
	# System & Desktop Apps (from desktopPackages / home.nix)
	# brave-bin
	zen-browser-bin
	xwayland-satellite-git
	gpu-screen-recorder
	labymod-launcher
	# sonobus-bin
	# mpvpaper-git
	localsend-bin
	pokemon-colorscripts-git
	waydroid
	proton-vpn-gtk-app
	xcursor-vimix
	sddm-astronaut-theme-git

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
	ripdrag-bin
)

log_info "Installing AUR packages via paru..."
paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"

log_success "AUR packages installation completed successfully!"
