#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_bw() {
    if command -v bw &>/dev/null; then
        echo "  Bitwarden CLI is already installed. Skipping."
        return 0
    fi

    echo "--> Installing Bitwarden CLI..."

    if ! command -v jq &>/dev/null; then
        apt-get install -y jq
    fi
    if ! command -v unzip &>/dev/null; then
        apt-get install -y unzip
    fi
    if ! command -v curl &>/dev/null; then
        apt-get install -y curl
    fi

    curl -sSL -o /tmp/bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
    unzip -o /tmp/bw.zip -d /tmp
    mv /tmp/bw /usr/local/bin/
    rm -f /tmp/bw.zip
    chmod +x /usr/local/bin/bw

    echo -e "  ${GREEN}✔ Bitwarden CLI installed.${NC}"
}

bw_configure_server() {
    local local_vaultwarden="https://vw.utsuwa.local"
    local public_bitwarden="https://vault.bitwarden.com"

    echo "Checking if local Vaultwarden ($local_vaultwarden) is online..."
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$local_vaultwarden" || echo "000")

    if [ "$http_status" -ne "000" ]; then
        echo "Local Vaultwarden is ONLINE (HTTP $http_status). Using local server..."
        bw config server "$local_vaultwarden"
    else
        echo "Local Vaultwarden is OFFLINE or unreachable. Falling back to public Bitwarden Cloud..."
        bw config server "$public_bitwarden"
    fi
}

bw_login() {
    bw login
    local session
    session=$(bw unlock --raw)
    export BW_SESSION="$session"
}

bw_get_item() {
    local item_name="$1"
    BW_SESSION="${BW_SESSION}" bw get item "$item_name"
}

bw_logout() {
    bw logout
    unset BW_SESSION
}
