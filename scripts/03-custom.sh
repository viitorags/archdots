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

DRY_RUN="${DRY_RUN:-false}"

log_section "Custom Installations & Services Phase"

REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ensure ~/.local/bin is in the script PATH so we can run bun if just installed
export PATH="$HOME/.local/bin:$PATH"

# 1. Install bun-baseline from GitHub release
install_bun_baseline() {
	if [ ! -f "$HOME/.local/bin/bun" ]; then
		log_info "Installing bun-baseline from GitHub..."
		if [ "$DRY_RUN" = "true" ]; then
			log_info "[DRY RUN] Would download and install bun-baseline to ~/.local/bin/bun"
			return 0
		fi

		mkdir -p "$HOME/.local/bin"
		local TEMP_DIR
		TEMP_DIR=$(mktemp -d)
		local TEMP_ZIP="$TEMP_DIR/bun.zip"

		# Download from GitHub releases
		if wget -q "https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64-baseline.zip" -O "$TEMP_ZIP"; then
			if command -v unzip &>/dev/null; then
				unzip -qo "$TEMP_ZIP" -d "$TEMP_DIR"
				# Find the bun executable inside the unzipped folder
				local BUN_BIN
				BUN_BIN=$(find "$TEMP_DIR" -type f -name "bun" | head -n 1)
				if [ -n "$BUN_BIN" ]; then
					install -Dm755 "$BUN_BIN" "$HOME/.local/bin/bun"
					log_success "bun-baseline successfully installed to ~/.local/bin/bun"
				else
					log_error_no_exit "Could not find bun binary in the extracted files."
				fi
			else
				log_error_no_exit "unzip command is not available. Please install unzip first."
			fi
		else
			log_error_no_exit "Failed to download bun-baseline from GitHub."
		fi
		rm -rf "$TEMP_DIR"
	else
		log_info "bun-baseline is already installed at ~/.local/bin/bun. Skipping..."
	fi
}

# 2. Install opencode via bun
install_opencode_via_bun() {
	if [ ! -f "$HOME/.bun/bin/opencode" ]; then
		if [ ! -x "$HOME/.local/bin/bun" ] && [ "$DRY_RUN" = "false" ]; then
			log_warning "bun-baseline is not installed or not executable. Skipping opencode installation."
			return 1
		fi

		log_info "Installing opencode via bun add -g opencode-ai..."
		if [ "$DRY_RUN" = "true" ]; then
			log_info "[DRY RUN] Would run: bun add -g opencode-ai"
			return 0
		fi

		# Run bun add -g opencode-ai
		if bun add -g opencode-ai; then
			log_success "opencode successfully installed via bun!"
		else
			log_error_no_exit "Failed to install opencode via bun."
		fi
	else
		log_success "opencode is already installed at ~/.bun/bin/opencode. Skipping..."
	fi
}

# Execute Bun and Opencode steps
install_bun_baseline
install_opencode_via_bun

# 3. Install composer global packages (laravel, laravel-pint)
if command -v composer &>/dev/null; then
	if [ ! -f "$HOME/.config/composer/vendor/bin/laravel" ] || [ ! -f "$HOME/.config/composer/vendor/bin/pint" ]; then
		if ask_confirm "Do you want to install Laravel installer and Laravel Pint globally via composer?" "y"; then
			log_info "Installing Laravel installer and Laravel Pint globally via composer..."
			if [ "$DRY_RUN" = "true" ]; then
				log_info "[DRY RUN] Would run: composer global require laravel/installer laravel/pint"
			else
				composer global require laravel/installer laravel/pint || log_warning "Failed to run composer global require."
				log_success "Composer global packages successfully installed!"
			fi
		fi
	else
		log_info "Laravel installer and Laravel Pint are already installed via composer. Skipping..."
	fi
else
	log_warning "composer is not available. Skipping global composer packages."
fi

# 4. Set up Flatpak and install configured flatpaks
if command -v flatpak &>/dev/null; then
	if ask_confirm "Do you want to configure Flathub and install Flatpaks (Sober, SpeedyNote)?" "n"; then
		log_info "Configuring Flatpak Flathub repository..."
		if [ "$DRY_RUN" = "true" ]; then
			log_info "[DRY RUN] Would run: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
			log_info "[DRY RUN] Would run: flatpak install -y flathub org.vinegarhq.Sober org.speedynote.SpeedyNote"
		else
			flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
			log_info "Installing Sober and SpeedyNote from Flathub..."
			flatpak install -y flathub org.vinegarhq.Sober || log_warning "Sober installation failed."
			flatpak install -y flathub org.speedynote.SpeedyNote || log_warning "SpeedyNote installation failed."
			log_success "Flatpaks setup completed."
		fi
	fi
else
	log_warning "flatpak is not available. Skipping flatpak packages."
fi

# 5. Enable Systemd Services
log_info "Enabling and starting systemd services..."
SERVICES=(
	docker
	avahi-daemon
	sddm
	upower
)

for SERVICE in "${SERVICES[@]}"; do
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would enable and start systemd service: ${SERVICE}"
	else
		if systemctl list-unit-files "${SERVICE}.service" &>/dev/null; then
			log_info "Enabling and starting ${SERVICE}..."
			sudo systemctl enable --now "${SERVICE}"
		else
			log_warning "Service ${SERVICE}.service not found."
		fi
	fi
done

# 6. Initialize Rustup stable toolchain
if command -v rustup &>/dev/null; then
	log_info "Checking Rust toolchain..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would ensure rustup stable toolchain is initialized"
	else
		if ! rustup show active-toolchain &>/dev/null; then
			log_info "Initializing rustup stable toolchain..."
			rustup default stable || log_warning "Failed to initialize rustup stable toolchain."
			log_success "Rust toolchain initialized successfully."
		else
			log_success "Rust toolchain is already active."
		fi
	fi
fi

# 7. Install Oh My Zsh (non-interactively)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	log_info "Installing Oh My Zsh..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would download and run Oh My Zsh installer"
	else
		TEMP_OMZ=$(mktemp)
		wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O "$TEMP_OMZ"
		RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$TEMP_OMZ" --unattended
		rm -f "$TEMP_OMZ"
		log_success "Oh My Zsh installed successfully!"
	fi
else
	log_info "Oh My Zsh is already installed. Skipping..."
fi

# 8. Change default shell to zsh safely
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [ "$CURRENT_SHELL" != "/usr/bin/zsh" ] && [ "$CURRENT_SHELL" != "/bin/zsh" ]; then
	log_info "Changing default shell to zsh..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would run: sudo chsh -s /usr/bin/zsh $USER"
	else
		sudo chsh -s /usr/bin/zsh "$USER"
		log_success "Default shell changed to zsh (will take effect on next login)."
	fi
fi

# 9. GTK bookmarks symlink
GTK3_BOOKMARKS_SRC="$REPO_DIR/config/gtk-3.0/bookmarks"
GTK3_BOOKMARKS_DST="$HOME/.config/gtk-3.0/bookmarks"
if [ -f "$GTK3_BOOKMARKS_SRC" ]; then
	log_info "Linking GTK bookmarks..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would run: ln -sf $GTK3_BOOKMARKS_SRC $GTK3_BOOKMARKS_DST"
	else
		mkdir -p "$HOME/.config/gtk-3.0"
		ln -sf "$GTK3_BOOKMARKS_SRC" "$GTK3_BOOKMARKS_DST"
		log_success "GTK bookmarks linked."
	fi
fi

# 11. Install custom binaries
BIN_SRC="$REPO_DIR/bin"
BIN_DST="$HOME/.local/bin"
if [ -d "$BIN_SRC" ]; then
	log_info "Installing custom binaries to $BIN_DST..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would copy $BIN_SRC to $BIN_DST and set +x"
	else
		mkdir -p "$BIN_DST"
		cp -r "$BIN_SRC/." "$BIN_DST/"
		chmod +x "$BIN_DST"/* 2>/dev/null
		log_success "Custom binaries installed."
	fi
else
	log_warning "bin/ directory not found in repository. Skipping."
fi

# 12. Install custom fonts
FONTS_SRC="$REPO_DIR/fonts"
FONTS_DST="$HOME/.local/share/fonts"
if [ -d "$FONTS_SRC" ]; then
	log_info "Installing custom fonts to $FONTS_DST..."
	if [ "$DRY_RUN" = "true" ]; then
		log_info "[DRY RUN] Would copy $FONTS_SRC to $FONTS_DST and run fc-cache -f"
	else
		mkdir -p "$FONTS_DST"
		cp -r "$FONTS_SRC/." "$FONTS_DST/"
		fc-cache -f
		log_success "Custom fonts installed and font cache updated!"
	fi
else
	log_warning "fonts/ directory not found in repository. Skipping."
fi

log_success "Custom installations and services setup process completed!"
