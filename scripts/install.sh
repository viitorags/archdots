#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Get directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions for logging
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
	log_error "Please do not run this script as root or using sudo. The script will ask for sudo when needed."
fi

echo "=========================================================="
echo " Starting Dependency Sync from NixOS Config to Arch Linux "
echo "=========================================================="
echo "This process will run three phases:"
echo "1. Install official Arch packages using pacman"
echo "2. Bootstrap paru (AUR helper) and install AUR packages"
echo "3. Run custom installs (opencode, claude-code, flatpaks) & services"
echo "=========================================================="
echo

RUN_PACMAN=false
RUN_AUR=false
RUN_CUSTOM=false
HAS_FLAGS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--pacman)
      RUN_PACMAN=true
      HAS_FLAGS=true
      shift
      ;;
    -a|--aur)
      RUN_AUR=true
      HAS_FLAGS=true
      shift
      ;;
    -c|--custom)
      RUN_CUSTOM=true
      HAS_FLAGS=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -p, --pacman   Install official Arch packages (Phase 1)"
      echo "  -a, --aur      Install AUR packages via paru (Phase 2)"
      echo "  -c, --custom   Run custom installations & services (Phase 3)"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1. Use -h or --help for usage."
      ;;
  esac
done

if [ "$HAS_FLAGS" = false ]; then
  RUN_PACMAN=true
  RUN_AUR=true
  RUN_CUSTOM=true
  
  # Ask for confirmation before running
  read -p "Do you want to proceed with the full installation? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled."
    exit 0
  fi
fi

# Step 1: Install official pacman packages
if [ "$RUN_PACMAN" = true ]; then
  if [ -f "$SCRIPT_DIR/01-pacman.sh" ]; then
    bash "$SCRIPT_DIR/01-pacman.sh"
  else
    log_error "01-pacman.sh not found."
  fi
  echo
fi

# Step 2: Install AUR packages via paru
if [ "$RUN_AUR" = true ]; then
  if [ -f "$SCRIPT_DIR/02-paru.sh" ]; then
    bash "$SCRIPT_DIR/02-paru.sh"
  else
    log_error "02-paru.sh not found."
  fi
  echo
fi

# Step 3: Custom configurations, flatpaks and systemd services
if [ "$RUN_CUSTOM" = true ]; then
  if [ -f "$SCRIPT_DIR/03-custom.sh" ]; then
    bash "$SCRIPT_DIR/03-custom.sh"
  else
    log_error "03-custom.sh not found."
  fi
  echo
fi

echo "=========================================================="
log_success "Dependency Synchronization Complete!"
echo " Note: Remember to add '~/.config/composer/vendor/bin'"
echo "       and '~/.bun/bin' to your PATH to use them."
echo "=========================================================="
