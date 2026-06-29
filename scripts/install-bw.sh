#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

header "                 BITWARDEN CLI INSTALL"

source "${SCRIPT_DIR}/../lib/bw.sh"
install_bw
