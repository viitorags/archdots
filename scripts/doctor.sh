#!/usr/bin/env bash
# shellcheck disable=SC2088
# (SC2088: tildes below are literal display text in messages, not paths to expand)

# Health check: verifies the dotfiles are actually applied on this system
# and flags drift/breakage without changing anything (read-only).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/utils.sh" ]; then
	source "$SCRIPT_DIR/utils.sh"
else
	echo -e "\e[31m[ERROR]\e[0m utils.sh not found."
	exit 1
fi

WARN_COUNT=0
FAIL_COUNT=0

pass() { echo -e "  ${GREEN}[OK]${RESET}   $1"; }
warn() {
	echo -e "  ${YELLOW}[WARN]${RESET} $1"
	((WARN_COUNT++)) || true
}
fail() {
	echo -e "  ${RED}[FAIL]${RESET} $1"
	((FAIL_COUNT++)) || true
}

log_section "Dotfiles Health Check"

# 1. config/* directories are in sync between repo and ~/.config
log_info "Checking config directories..."
if [ -d "$REPO_DIR/config" ]; then
	for dir in "$REPO_DIR/config"/*; do
		[ -d "$dir" ] || continue
		name="$(basename "$dir")"
		target="$HOME/.config/$name"
		if [ ! -e "$target" ]; then
			fail "~/.config/$name missing (run sync-to-system.sh)"
		elif diff -rq "$dir" "$target" >/dev/null 2>&1; then
			pass "~/.config/$name matches repo"
		else
			warn "~/.config/$name differs from repo (run sync.sh to check)"
		fi
	done
fi

# 2. .zshrc in sync
if [ -f "$REPO_DIR/.zshrc" ]; then
	if [ ! -f "$HOME/.zshrc" ]; then
		fail "~/.zshrc missing"
	elif diff -q "$REPO_DIR/.zshrc" "$HOME/.zshrc" >/dev/null 2>&1; then
		pass "~/.zshrc matches repo"
	else
		warn "~/.zshrc differs from repo"
	fi
fi

# 3. GTK bookmarks symlink must point into the repo and resolve to a real file
log_info "Checking GTK bookmarks symlink..."
GTK_LINK="$HOME/.config/gtk-3.0/bookmarks"
GTK_SRC="$REPO_DIR/config/gtk-3.0/bookmarks"
if [ -L "$GTK_LINK" ]; then
	if [ ! -e "$GTK_LINK" ]; then
		fail "GTK bookmarks symlink is broken (points to nonexistent/self target)"
	elif [ "$(readlink -f "$GTK_LINK")" = "$(readlink -f "$GTK_SRC" 2>/dev/null)" ]; then
		pass "GTK bookmarks symlink OK"
	else
		warn "GTK bookmarks symlink points elsewhere than $GTK_SRC"
	fi
elif [ -e "$GTK_LINK" ]; then
	fail "GTK bookmarks exists but is a regular file, not a symlink (sync bug may have struck again)"
else
	warn "GTK bookmarks symlink not set up (run 03-custom.sh)"
fi

# 4. bin/ binaries installed and executable
log_info "Checking custom binaries..."
if [ -d "$REPO_DIR/bin" ]; then
	for f in "$REPO_DIR/bin"/*; do
		name="$(basename "$f")"
		target="$HOME/.local/bin/$name"
		if [ ! -e "$target" ]; then
			fail "~/.local/bin/$name missing"
		elif [ ! -x "$target" ]; then
			fail "~/.local/bin/$name not executable"
		else
			pass "~/.local/bin/$name installed"
		fi
	done
fi

# 5. Fonts installed
if [ -d "$REPO_DIR/fonts" ] && [ -n "$(ls -A "$REPO_DIR/fonts" 2>/dev/null)" ]; then
	if [ -d "$HOME/.local/share/fonts" ] && [ -n "$(ls -A "$HOME/.local/share/fonts" 2>/dev/null)" ]; then
		pass "Custom fonts installed"
	else
		fail "fonts/ defined in repo but ~/.local/share/fonts is empty"
	fi
fi

# 6. Key dependencies present
log_info "Checking dependencies..."
for cmd in git rsync zsh niri kitty yazi; do
	if command -v "$cmd" &>/dev/null; then
		pass "$cmd found"
	else
		warn "$cmd not found in PATH"
	fi
done

# 7. Default shell is zsh
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" == *zsh ]]; then
	pass "Default shell is zsh"
else
	warn "Default shell is $CURRENT_SHELL, not zsh"
fi

# 8. Oh My Zsh installed
if [ -d "$HOME/.oh-my-zsh" ]; then
	pass "Oh My Zsh installed"
else
	warn "Oh My Zsh not installed"
fi

echo
log_section "Summary"
if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
	log_success "Everything looks good!"
elif [ "$FAIL_COUNT" -eq 0 ]; then
	log_warning "$WARN_COUNT warning(s) found."
else
	log_error_no_exit "$FAIL_COUNT failure(s), $WARN_COUNT warning(s) found."
	exit 1
fi
