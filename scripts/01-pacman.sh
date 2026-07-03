#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared utilities
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
	source "$SCRIPT_DIR/utils.sh"
else
	echo -e "\e[31m[ERROR]\e[0m utils.sh not found."
	exit 1
fi

DRY_RUN="${DRY_RUN:-false}"

log_info "Starting Arch Linux Official Packages Phase..."

# Enable ParallelDownloads in /etc/pacman.conf if not already active
if [ -f /etc/pacman.conf ]; then
	if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
		if [ "$DRY_RUN" = "true" ]; then
			log_info "[DRY RUN] Would enable parallel downloads in /etc/pacman.conf"
		else
			log_info "Enabling parallel downloads in /etc/pacman.conf..."
			sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
			log_success "Parallel downloads enabled!"
		fi
	elif grep -q "^ParallelDownloads" /etc/pacman.conf; then
		log_success "Parallel downloads already enabled in /etc/pacman.conf."
	else
		log_warning "Could not find ParallelDownloads configuration in /etc/pacman.conf."
	fi
fi

# Update package database
if [ "$DRY_RUN" = "true" ]; then
	log_info "[DRY RUN] Would update pacman database: sudo pacman -Syu --noconfirm"
else
	log_info "Updating pacman database..."
	sudo pacman -Syu --noconfirm
fi

# Categorized packages matching the NixOS configuration
CORE_PACKAGES=(
	# Core CLI Tools (from corePackages)
	tree
	wget
	git
	unzip
	zip
	zsh
	zsh-autosuggestions
	zsh-syntax-highlighting
	eza
	docker
	docker-compose
	iptables

	# Dev Utilities & Shell (from dev/default.nix / home/programs/direnv / btop)
	direnv
	btop
	fastfetch
	rclone
	fd
	jq
	ripgrep
	shellcheck
	make
	git-delta # equivalent to nix's delta
	shfmt
)

DESKTOP_PACKAGES=(
	# Desktop Utilities (from desktopPackages)
	unrar
	ffmpeg
	brightnessctl
	avahi
	upower
	exfatprogs
	yt-dlp
	dconf
	telegram-desktop
	ark
	gparted
	mpv
	freerdp
	grim
	slurp
	wl-clipboard
	wtype
	cliphist
	pamixer
	pavucontrol
	libei
	obsidian
	cowsay
	cmatrix
	papirus-icon-theme
	virt-manager
	qemu-base

	# File manager and GTK/GNOME (from home.nix / default.nix)
	gvfs
	nautilus
	imagemagick
	xournalpp
	swappy
	wf-recorder
	gifski
	zbar
	translate-shell
	tesseract
	krita
	system-config-printer
	libreoffice-fresh
	obs-studio
	ppsspp
	anki
	evtest
	gamemode
	util-linux
	cava

	# Window Managers / Desktop Environments / Display Managers
	niri
	sddm
	polkit-gnome
	flatpak

	# Terminal Emulators
	kitty

	# PDF Viewer & CLI helpers (from yazi / sioyek)
	ouch
	glow
)

DEV_PACKAGES=(
	# Development Languages & Runtimes
	neovim
	nodejs
	npm
	pnpm
	php
	composer
	clang
	gcc
	cmake
	pkgconf
	jdk-openjdk # openjdk25 or default jdk
	go
	rustup # Recommended over raw rustc/cargo on Arch
	openssl
	python
	android-tools

	# Libraries
	qt5-graphicaleffects
	qt6-5compat
	qt6ct
	qt6-multimedia
	qt6-declarative
	kvantum
	qt5ct
)

FONTS=(
	# Fonts (from fonts.packages in packages.nix)
	otf-font-awesome
	noto-fonts
	noto-fonts-cjk
	noto-fonts-emoji
	ttf-dejavu
)

# Helper function to install packages with fallback to individual installs if bulk fails
install_packages_with_fallback() {
	local category="$1"
	shift
	local pkgs=("${@}")

	log_info "Installing $category packages..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would run: sudo pacman -S --needed --noconfirm ${pkgs[*]}"
		return 0
	fi

	if ! sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
		log_warning "Failed to install some packages in bulk. Attempting to install individually to isolate errors..."
		local failed_pkgs=()
		for pkg in "${pkgs[@]}"; do
			if ! sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
				log_error_no_exit "Failed to install package: $pkg"
				failed_pkgs+=("$pkg")
			fi
		done
		if [ ${#failed_pkgs[@]} -ne 0 ]; then
			log_warning "The following packages in category '$category' could not be installed: ${failed_pkgs[*]}"
		else
			log_success "All $category packages installed after individual retry!"
		fi
	else
		log_success "$category packages installation completed."
	fi
}

# Run the installation
install_packages_with_fallback "Core CLI" "${CORE_PACKAGES[@]}"
install_packages_with_fallback "Desktop & GUI" "${DESKTOP_PACKAGES[@]}"
install_packages_with_fallback "Development" "${DEV_PACKAGES[@]}"
install_packages_with_fallback "Fonts" "${FONTS[@]}"

log_success "Official packages installation process completed!"

if [ "$DRY_RUN" = "false" ]; then
	log_info "Verifying installed packages..."
	MISSING_PKGS=()
	for pkg in "${CORE_PACKAGES[@]}" "${DESKTOP_PACKAGES[@]}" "${DEV_PACKAGES[@]}" "${FONTS[@]}"; do
		pacman -Q "$pkg" &>/dev/null || MISSING_PKGS+=("$pkg")
	done
	if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
		log_warning "Packages not found after install: ${MISSING_PKGS[*]}"
	else
		log_success "All packages verified."
	fi
fi
