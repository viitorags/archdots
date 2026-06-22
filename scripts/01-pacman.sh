#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Helper functions for logging
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
log_error() {
	echo -e "\e[31m[ERROR]\e[0m $1"
	exit 1
}

echo "========================================="
echo " Installing Arch Linux Official Packages "
echo "========================================="

# Enable ParallelDownloads in /etc/pacman.conf if not already active
if [ -f /etc/pacman.conf ]; then
	if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
		log_info "Enabling parallel downloads in /etc/pacman.conf..."
		sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
		log_success "Parallel downloads enabled!"
	elif grep -q "^ParallelDownloads" /etc/pacman.conf; then
		log_success "Parallel downloads already enabled in /etc/pacman.conf."
	else
		log_warning "Could not find ParallelDownloads configuration in /etc/pacman.conf."
	fi
fi

# Update package database
log_info "Updating pacman database..."
sudo pacman -Syu --noconfirm

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
	lefthook
)

DESKTOP_PACKAGES=(
	# Desktop Utilities (from desktopPackages)
	unrar
	ffmpeg
	brightnessctl
	qemu-desktop
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

	# File manager and GTK/GNOME (from home.nix / default.nix)
	gvfs
	nautilus
	imagemagick
	qimgv
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

	# Window Managers / Desktop Environments / Display Managers
	hyprland
	sddm
	polkit-gnome
	flatpak

	# Terminal Emulators
	kitty

	# PDF Viewer & CLI helpers (from yazi / sioyek)
	sioyek
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
	php-cs-fixer
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

# Install Core packages
log_info "Installing Core CLI packages..."
sudo pacman -S --needed --noconfirm "${CORE_PACKAGES[@]}"

# Install Desktop/GUI packages
log_info "Installing Desktop & GUI packages..."
sudo pacman -S --needed --noconfirm "${DESKTOP_PACKAGES[@]}"

# Install Development packages
log_info "Installing Development environment packages..."
sudo pacman -S --needed --noconfirm "${DEV_PACKAGES[@]}"

# Install Fonts
log_info "Installing Fonts..."
sudo pacman -S --needed --noconfirm "${FONTS[@]}"

log_success "Official packages installation completed successfully!"
