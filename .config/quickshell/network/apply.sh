#!/usr/bin/env bash
# Re-apply the network panel QR-sharing override to the Quickshell Rise bar
# (V1 and V2).
#
# Quickshell Rise's updater replaces the whole ~/.config/quickshell/bar tree on
# every update, wiping these files. Sources live here; this script re-syncs them
# into the bar (idempotent, no-op when content is identical). Wired together
# with the night-light/weather/now-playing reapply through
# qs-nightlight-reapply.service.
set -u

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${QSRISE_BAR_DIR:-$HOME/.config/quickshell/bar}"
LOG="${QSRISE_NETWORK_LOG:-$HOME/.local/state/quickshell-rise/network-apply.log}"
mkdir -p "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

if [ "${1:-}" = "--delay" ]; then sleep "${2:-2}"; fi

if [ ! -f "$DEST/shell.qml" ]; then
    log "bar tree not found at $DEST (skipping)"
    exit 0
fi

[ -x "$SRC_DIR/wifi-qr.sh" ] || log "warning: $SRC_DIR/wifi-qr.sh is missing or not executable"

changed=0
sync_file() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    changed=1
}

# ── V1 tree ──
sync_file "$SRC_DIR/NetworkPanel.qml" "$DEST/panels/NetworkPanel.qml"

# ── V2 variant tree ──
V2_DIR="$DEST/variants/V2"
if [ -d "$V2_DIR/panels" ]; then
    sync_file "$SRC_DIR/v2/NetworkPanel.qml" "$V2_DIR/panels/NetworkPanel.qml"
fi

if [ "$changed" -eq 1 ]; then
    log "network QR override applied to $DEST"
else
    log "network QR override already up to date"
fi
exit 0
