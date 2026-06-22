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
echo "  Running Custom Installations & Services "
echo "========================================="

# 1. Install opencode from GitHub release (matches pkgs/opencode/package.nix version 1.17.9)
# if [ ! -f /usr/local/bin/opencode ]; then
#     log_info "Installing opencode from anomalyco/opencode GitHub releases..."
#     OPENCODE_VERSION="1.17.9"
#     TEMP_DIR=$(mktemp -d)
#     wget -q "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64-baseline.tar.gz" -O "$TEMP_DIR/opencode.tar.gz"
#     tar -xzf "$TEMP_DIR/opencode.tar.gz" -C "$TEMP_DIR"
#     sudo install -Dm755 "$TEMP_DIR/opencode" /usr/local/bin/opencode
#     rm -rf "$TEMP_DIR"
#     log_success "opencode successfully installed to /usr/local/bin/opencode"
# else
#     log_info "opencode is already installed. Skipping..."
# fi
#
# # 2. Install claude-code via npm globally
# if command -v npm &> /dev/null; then
#     if ! command -v claude &> /dev/null; then
#         log_info "Installing @claudecode/cli globally via npm..."
#         if [ -w "$(npm config get prefix)" ]; then
#             npm install -g @claudecode/cli
#         else
#             log_info "NPM prefix is not user-writable, using sudo..."
#             sudo npm install -g @claudecode/cli
#         fi
#         log_success "claude-code successfully installed!"
#     else
#         log_info "claude-code is already installed. Skipping..."
#     fi
# else
#     log_warning "npm is not available. Skipping claude-code installation."
# fi
#
# # 3. Install composer global packages (laravel, laravel-pint)
# if command -v composer &> /dev/null; then
#     if [ ! -f "$HOME/.config/composer/vendor/bin/laravel" ] || [ ! -f "$HOME/.config/composer/vendor/bin/pint" ]; then
#         log_info "Installing Laravel installer and Laravel Pint globally via composer..."
#         composer global require laravel/installer laravel/pint || log_warning "Failed to run composer global require."
#         log_success "Composer global packages successfully installed!"
#     else
#         log_info "Laravel installer and Laravel Pint are already installed via composer. Skipping..."
#     fi
#     log_info "Make sure ~/.config/composer/vendor/bin is in your PATH."
# else
#     log_warning "composer is not available. Skipping global composer packages."
# fi
#
# # 4. Set up Flatpak and install configured flatpaks
# if command -v flatpak &> /dev/null; then
#     log_info "Configuring Flatpak Flathub repository..."
#     flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
#
#     log_info "Installing Sober and SpeedyNote from Flathub..."
#     flatpak install -y flathub org.vinegarhq.Sober || log_warning "Sober installation failed."
#     flatpak install -y flathub org.speedynote.SpeedyNote || log_warning "SpeedyNote installation failed."
#     log_success "Flatpaks setup completed."
# else
#     log_warning "flatpak is not available. Skipping flatpak packages."
# fi

# 5. Enable Systemd Services (matching NixOS service configurations)
log_info "Enabling and starting systemd services..."
SERVICES=(
	docker
	avahi-daemon
	sddm
	upower
)

for SERVICE in "${SERVICES[@]}"; do
	if systemctl list-unit-files "${SERVICE}.service" &>/dev/null; then
		log_info "Enabling and starting ${SERVICE}..."
		sudo systemctl enable --now "${SERVICE}"
	else
		log_warning "Service ${SERVICE}.service not found."
	fi
done

# 6. Initialize Rustup stable toolchain
if command -v rustup &>/dev/null; then
	log_info "Checking Rust toolchain..."
	if ! rustup show active-toolchain &>/dev/null; then
		log_info "Initializing rustup stable toolchain..."
		rustup default stable || log_warning "Failed to initialize rustup stable toolchain."
		log_success "Rust toolchain initialized successfully."
	else
		log_success "Rust toolchain is already active."
	fi
fi

# 7. Install Oh My Zsh (non-interactively)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	log_info "Installing Oh My Zsh..."
	TEMP_OMZ=$(mktemp)
	wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O "$TEMP_OMZ"
	RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$TEMP_OMZ" --unattended
	rm -f "$TEMP_OMZ"
	log_success "Oh My Zsh installed successfully!"
else
	log_info "Oh My Zsh is already installed. Skipping..."
fi

# 8. Change default shell to zsh safely
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [ "$CURRENT_SHELL" != "/usr/bin/zsh" ] && [ "$CURRENT_SHELL" != "/bin/zsh" ]; then
	log_info "Changing default shell to zsh..."
	sudo chsh -s /usr/bin/zsh "$USER"
	log_success "Default shell changed to zsh (will take effect on next login)."
fi

log_success "Custom installations and services setup completed successfully!"
