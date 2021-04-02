#!/bin/bash

set -e

#############################################################################
#                                                                           #
#                     Pterodactyl Instalador Script                         #
#                                                                           #
#       Copyright (C) 2021, KaduPrays, <fabomegaxd@hotmail.com.br>          #
#                                                                           #
#############################################################################

SCRIPT_VERSION="v0.1.0"

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

output() {
  echo -e "* ${1}"
}

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

done=false

output "Instalação pterodactyl skript @ $SCRIPT_VERSION"
output
output "Copyright (C) 2021, KaduPrays#4208, <fabiomegaxd@hotmail.com.br"
output "https://github.com/kaduprays/pterodactyl-installer"
output
output "Qual quer duvida, ajuda, erro reporte em meu discord"
output "KaduPrays#4208"

output

panel() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/$SCRIPT_VERSION/install-panel.sh)
}

wings() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/$SCRIPT_VERSION/install-wings.sh)
}

legacy_panel() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/$SCRIPT_VERSION/legacy/panel_0.7.sh)
}

legacy_wings() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/$SCRIPT_VERSION/legacy/daemon_0.6.sh)
}

canary_panel() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/master/install-panel.sh)
}

canary_wings() {
  bash <(curl -s https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/master/install-wings.sh)
}

while [ "$done" == false ]; do
  options=(
    "Instalar painel 1.3.1"
    "Instalar wings 1.3.1"
    "Instalar o painel e a wings na mesma maquina * Skript executado na mesma maquina!\n"

    "Instalar painel 0.7"
    "Instalar daemon 0.6"
    "Instalar painel 0.7 daemon 0.6 na mesma maquina * Não recomandando\n"
  )

  actions=(
    "panel"
    "wings"
    "panel; wings"

    "legacy_panel"
    "legacy_wings"
    "legacy_panel; legacy_wings"
  )

  output "Qual você quer instalar?"

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]}-1)): "
  read -r action

  [ -z "$action" ] && error "Opção invalida!" && continue

  valid_input=("$(for ((i=0;i<=${#actions[@]}-1;i+=1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Opção invalida!"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && eval "${actions[$action]}"
done
