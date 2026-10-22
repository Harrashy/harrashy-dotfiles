#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup of existing config
backup() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        warn "Backing up existing $target to $backup"
        mv "$target" "$backup"
    fi
}

# Symlink a single file
link_file() {
    local src="$1"
    local dst="$2"
    backup "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    info "Linked $dst -> $src"
}

# Symlink a directory
link_dir() {
    local src="$1"
    local dst="$2"
    backup "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    info "Linked $dst -> $src"
}

echo "=== Dotfiles Installer ==="
echo ""

# Shell configs
info "Linking shell configs..."
link_file "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
link_file "$DOTFILES_DIR/.bash_logout" "$HOME/.bash_logout"

# Starship prompt
info "Linking starship config..."
link_file "$DOTFILES_DIR/.config/starship.toml" "$CONFIG_DIR/starship.toml"

# Hyprland
info "Linking Hyprland config..."
link_dir "$DOTFILES_DIR/.config/hypr" "$CONFIG_DIR/hypr"

# Neovim
info "Linking Neovim config..."
link_dir "$DOTFILES_DIR/.config/nvim" "$CONFIG_DIR/nvim"

# Terminals
info "Linking terminal configs..."
link_dir "$DOTFILES_DIR/.config/alacritty" "$CONFIG_DIR/alacritty"
link_dir "$DOTFILES_DIR/.config/foot" "$CONFIG_DIR/foot"
link_dir "$DOTFILES_DIR/.config/ghostty" "$CONFIG_DIR/ghostty"
link_dir "$DOTFILES_DIR/.config/kitty" "$CONFIG_DIR/kitty"

# Tools
info "Linking tool configs..."
link_dir "$DOTFILES_DIR/.config/btop" "$CONFIG_DIR/btop"
link_dir "$DOTFILES_DIR/.config/lazygit" "$CONFIG_DIR/lazygit"
link_dir "$DOTFILES_DIR/.config/mise" "$CONFIG_DIR/mise"
link_dir "$DOTFILES_DIR/.config/cava" "$CONFIG_DIR/cava"
link_dir "$DOTFILES_DIR/.config/fcitx5" "$CONFIG_DIR/fcitx5"
link_dir "$DOTFILES_DIR/.config/omarchy" "$CONFIG_DIR/omarchy"

# Quickshell Rise overrides (kept outside the updater-managed bar tree)
info "Linking Quickshell Rise overrides..."
link_dir "$DOTFILES_DIR/.config/quickshell/nightlight" "$CONFIG_DIR/quickshell/nightlight"
link_dir "$DOTFILES_DIR/.config/quickshell/weather"    "$CONFIG_DIR/quickshell/weather"
link_dir "$DOTFILES_DIR/.config/quickshell/mpris"      "$CONFIG_DIR/quickshell/mpris"

info "Linking Quickshell reapply watcher..."
link_file "$DOTFILES_DIR/.config/systemd/user/qs-nightlight-reapply.path"    "$CONFIG_DIR/systemd/user/qs-nightlight-reapply.path"
link_file "$DOTFILES_DIR/.config/systemd/user/qs-nightlight-reapply.service" "$CONFIG_DIR/systemd/user/qs-nightlight-reapply.service"
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload || true
    systemctl --user enable --now qs-nightlight-reapply.path || \
        warn "Could not enable qs-nightlight-reapply.path; enable it manually after login."
fi

# OpenCode
info "Linking OpenCode config..."
link_file "$DOTFILES_DIR/.config/opencode.json" "$CONFIG_DIR/opencode.json"

echo ""
info "All dotfiles linked successfully!"
echo ""
echo "To pull latest changes: cd $DOTFILES_DIR && git pull"
echo "To push changes: cd $DOTFILES_DIR && git add . && git commit -m 'update' && git push"
