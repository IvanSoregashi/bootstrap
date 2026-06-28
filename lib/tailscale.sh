#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_tailscale() {
    if command -v tailscale &>/dev/null; then
        echo "  Tailscale is already installed. Skipping."
        return 0
    fi

    if ping -c 1 -W 1 seki &>/dev/null; then
        echo -e "  ${YELLOW}Local router 'seki' is reachable — Tailnet may already be available.${NC}"
        read -r -p "  Still install Tailscale? (y/n) [n]: " install_ts
        install_ts=${install_ts:-n}
        if [[ ! "$install_ts" =~ ^[Yy]$ ]]; then
            echo "  Skipping Tailscale install."
            return 0
        fi
    fi

    echo "--> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh

    echo -e "  ${GREEN}✔ Tailscale installed.${NC}"
    echo "  Connect to your tailnet with: sudo tailscale up"
    echo "  Or use an auth key: sudo tailscale up --authkey=tskey-..."
}
