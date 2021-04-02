#!/bin/bash

set -e

SCRIPT_PATH="/tmp/panel_install_0.7.sh"

if [[ $EUID -ne 0 ]]; then
  echo "* Este script deve ser executado com privilégios de root (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl é necessário para que este script funcione."
  echo "* instalar usando apt (Debian e derivados) ou yum / dnf (CentOS)"
  exit 1
fi

dl_script() {
    rm -rf "$SCRIPT_PATH"
    curl -o "$SCRIPT_PATH" https://raw.githubusercontent.com/vilhelmprytz/pterodactyl-installer/b8e298003fe3120edccb02fabc5d7e86daef22e6/install-panel.sh
    chmod +x "$SCRIPT_PATH"
}

replace() {
    sed -i 's/master/b8e298003fe3120edccb02fabc5d7e86daef22e6/g' "$SCRIPT_PATH"
    sed -i '/PTERODACTYL_VERSION=/c\PTERODACTYL_VERSION="v0.7.19"' "$SCRIPT_PATH"
    sed -i 's*https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz*https://github.com/pterodactyl/panel/releases/download/v0.7.19/panel.tar.gz*g' "$SCRIPT_PATH"

    sed -i 's/--filename=composer/--filename=composer --version=1.10.17/g' "$SCRIPT_PATH"
}

main() {
    dl_script
    replace
    bash "$SCRIPT_PATH"
}

main
