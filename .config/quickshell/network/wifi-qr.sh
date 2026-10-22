#!/usr/bin/env bash
# Generate a Wi-Fi QR code for a saved NetworkManager connection.
#
# Usage: wifi-qr.sh <connection-uuid> <ssid> <output.png>
#
# Exit codes:
#   0  QR written to <output.png>
#   3  the saved passphrase is not readable by this user
#   4  this security type cannot be shared with a Wi-Fi QR code
#   5  qrencode failed
set -u

uuid="${1:-}"
ssid="${2:-}"
out="${3:-}"

if [ -z "$uuid" ] || [ -z "$ssid" ] || [ -z "$out" ]; then
    exit 4
fi

km="$(nmcli -g 802-11-wireless-security.key-mgmt connection show uuid "$uuid" 2>/dev/null)"
pskless=0
case "$km" in
    wpa-psk|sae) pskless=0 ;;
    ''|none|owe) pskless=1 ;;
    *) exit 4 ;;   # enterprise / 802.1X / LEAP: a plain Wi-Fi QR cannot carry it
esac

if [ "$pskless" = 1 ]; then
    # key-mgmt "none" with a WEP key is not representable by the Wi-Fi QR format.
    wep="$(nmcli -g 802-11-wireless-security.wep-key0 connection show uuid "$uuid" 2>/dev/null)"
    [ -z "$wep" ] || exit 4
fi

psk=""
if [ "$pskless" = 0 ]; then
    psk="$(nmcli -s -g 802-11-wireless-security.psk connection show uuid "$uuid" 2>/dev/null)"
    [ -n "$psk" ] || exit 3
fi

# Escape the characters that are special inside a WIFI: QR payload.
esc() {
    local val="$1" out="" c i
    for ((i = 0; i < ${#val}; i++)); do
        c="${val:i:1}"
        case "$c" in
            '\\'|';'|','|':'|'"') out="$out\\$c" ;;
            *) out="$out$c" ;;
        esac
    done
    printf '%s' "$out"
}

s="$(esc "$ssid")"
if [ "$pskless" = 0 ]; then
    payload="WIFI:T:WPA;S:$s;P:$(esc "$psk");H:false;;"
else
    payload="WIFI:T:nopass;S:$s;;"
fi

qrencode -t PNG -s 6 -m 2 -o "$out" "$payload" >/dev/null 2>&1 || exit 5
