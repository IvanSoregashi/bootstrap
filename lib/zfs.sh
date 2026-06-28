#!/bin/bash

parse_to_bytes() {
    local input="$1"
    input=$(echo "$input" | xargs | tr '[:lower:]' '[:upper:]')
    if [[ "$input" =~ ^[0-9]+G$ ]]; then
        local num="${input%G}"
        echo "$((num * 1024 * 1024 * 1024))"
    elif [[ "$input" =~ ^[0-9]+M$ ]]; then
        local num="${input%M}"
        echo "$((num * 1024 * 1024))"
    elif [[ "$input" =~ ^[0-9]+K$ ]]; then
        local num="${input%K}"
        echo "$((num * 1024))"
    elif [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "$input"
    else
        echo "0"
    fi
}

zfs_calculate_arc() {
    if [ ! -f /proc/meminfo ]; then
        echo "1G"
        return
    fi
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local suggest_bytes=$((total_ram_kb * 1024 / 4))
    local suggest_gb=$((suggest_bytes / 1024 / 1024 / 1024))
    if [ "$suggest_gb" -gt 0 ]; then
        echo "${suggest_gb}G"
    else
        echo "512M"
    fi
}

zfs_create_pool() {
    local pool_name="$1"
    local pool_type="$2"
    shift 2
    local disks=("$@")

    local zpool_args=(
        create -f -o ashift=12
        -O acltype=posixacl
        -O xattr=sa
        -O dnodesize=auto
        -O normalization=formD
        -O devices=off
        "$pool_name"
    )

    if [ "$pool_type" = "mirror" ]; then
        zpool_args+=(mirror)
    fi

    for disk in "${disks[@]}"; do
        zpool_args+=("$disk")
    done

    run zpool "${zpool_args[@]}"
}

zfs_create_encrypted_dataset() {
    local pool_name="$1"
    local dataset_name="$2"

    run zfs create \
        -o encryption=on \
        -o keyformat=passphrase \
        -o keylocation=prompt \
        "${pool_name}/${dataset_name}"
}

zfs_configure_arc() {
    local arc_bytes="$1"
    run mkdir -p /etc/modprobe.d
    echo "options zfs zfs_arc_max=${arc_bytes}" | run tee /etc/modprobe.d/zfs.conf > /dev/null
    run update-initramfs -u -k all
}

zfs_check_installed() {
    command -v zfs &>/dev/null && command -v zpool &>/dev/null
}

zfs_module_loaded() {
    lsmod | grep -q zfs 2>/dev/null
}

zfs_ensure_installed() {
    if zfs_check_installed; then
        echo "  ZFS tools already installed. Skipping."
        return 0
    fi

    if ! os_is_debian; then
        error "ZFS installation is only automated for Debian. Install manually."
        exit 1
    fi

    echo -e "${YELLOW}Note: Compiling ZFS kernel modules via DKMS may take several minutes.${NC}"
    read -r -p "Install ZFS utilities now? (y/n) [y]: " inst_zfs
    inst_zfs=${inst_zfs:-y}
    if [[ ! "$inst_zfs" =~ ^[Yy]$ ]]; then
        error "ZFS setup aborted."
        exit 1
    fi

    if ! apt-cache show zfsutils-linux &>/dev/null; then
        echo "  Enabling 'contrib' and 'non-free' package sources for ZFS..."

        if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then
            sed -i -E 's/^(Components:.*main)(.*)/\1 contrib non-free non-free-firmware\2/' /etc/apt/sources.list.d/debian.sources
            sed -i -E 's/contrib contrib/contrib/g; s/non-free non-free/non-free/g; s/non-free-firmware non-free-firmware/non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
        fi

        if [ -f "/etc/apt/sources.list" ]; then
            sed -i -E '/^deb/ s/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list
            sed -i -E 's/contrib contrib/contrib/g; s/non-free non-free/non-free/g; s/non-free-firmware non-free-firmware/non-free-firmware/g' /etc/apt/sources.list
        fi

        apt-get update

        if ! apt-cache show zfsutils-linux &>/dev/null; then
            error "ZFS packages still not visible. Check internet connection."
            exit 1
        fi
        echo -e "${GREEN}✔ Repository components enabled.${NC}"
    fi

    echo "--> Installing ZFS packages..."
    apt-get install -y linux-headers-amd64 zfs-dkms zfsutils-linux

    echo "--> Loading ZFS kernel module..."
    modprobe zfs || { error "Error loading ZFS module. Reboot may be required."; exit 1; }
    echo -e "${GREEN}✔ ZFS installed and loaded.${NC}"
}
