#!/bin/bash

set -e

GITHUB_SOURCE="master"
SCRIPT_RELEASE="canary"

#################################
######## General checks #########
#################################

# exit with error status code if user is not root
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

#################################
########## Variables ############
#################################

# download URLs
WINGS_DL_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
GITHUB_BASE_URL="https://raw.githubusercontent.com/kaduprays/pterodactyl-installer/$GITHUB_SOURCE"

COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

INSTALL_MARIADB=false

# firewall
CONFIGURE_FIREWALL=false
CONFIGURE_UFW=false
CONFIGURE_FIREWALL_CMD=false

# SSL (Let's Encrypt)
CONFIGURE_LETSENCRYPT=false
FQDN=""
EMAIL=""

#################################
####### Version checking ########
#################################

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

echo "* Recuperando informações de lançamento .."
WINGS_VERSION="$(get_latest_release "pterodactyl/wings")"

#################################
####### Visual functions ########
#################################

print_error() {
  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

print_warning() {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

print_brake() {
  for ((n=0;n<$1;n++));
    do
      echo -n "#"
    done
    echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

#################################
####### OS check funtions #######
#################################

detect_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

check_os_comp() {
  SUPPORTED=false

  MACHINE_TYPE=$(uname -m)
  if [ "${MACHINE_TYPE}" != "x86_64" ]; then # check the architecture
    print_warning "Arquitetura detectada $MACHINE_TYPE"
    print_warning "O uso de qualquer outra arquitetura diferente de 64 bits (x86_64) causará problemas."

    echo -e -n  "* Tem certeza de que deseja continuar? (Y/N):"
    read -r choice

    if [[ ! "$choice" =~ [Yy] ]]; then
      print_error "Instalação abortada"
      exit 1
    fi
  fi

  case "$OS" in
    ubuntu)
      [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
      ;;
    debian)
      [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
      ;;
    centos)
      [ "$OS_VER_MAJOR" == "7" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
      ;;
    *)
      SUPPORTED=false ;;
  esac

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER é suportado."
  else
    echo "* $OS $OS_VER não é suportado."
    print_error "SO não suportado"
    exit 1
  fi

  # check virtualization
  echo -e  "* Instalando o virt-what ..."
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    # silence dpkg output
    export DEBIAN_FRONTEND=noninteractive

    # install virt-what
    apt-get -y update -qq
    apt-get install -y virt-what -qq

    # unsilence
    unset DEBIAN_FRONTEND
  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      yum -q -y update

      # install virt-what
      yum -q -y install virt-what
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      dnf -y -q update

      # install virt-what
      dnf install -y -q virt-what
    fi
  else
    print_error "OS invalida."
    exit 1
  fi

  virt_serv=$(virt-what)

  case "$virt_serv" in
    openvz | lxc)
      print_warning "Tipo não compatível de virtualização detectado. Consulte seu provedor de hospedagem se o seu servidor pode executar Docker ou não. Prossiga por sua conta e risco."
      print_error "Instalação abortada!"
      exit 1
      ;;
    *)
      [ "$virt_serv" != "" ] && print_warning "Virtualization: $virt_serv detected."
      ;;
  esac

  if uname -r | grep -q "xxxx"; then
    print_error "Kernel não compatível detectado."
    exit 1
  fi
}

apt_update() {
  apt update -q -y && apt upgrade -y
}

yum_update() {
  yum -y update
}

dnf_update() {
  dnf -y upgrade
}

enable_docker(){
  systemctl start docker
  systemctl enable docker
}

install_docker() {
  echo "* Instalando docker .."
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    # Install dependencies
    apt-get -y install \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      software-properties-common

    # Add docker gpg key
    curl -fsSL https://download.docker.com/linux/"$OS"/gpg | apt-key add -

    # Show fingerprint to user
    apt-key fingerprint 0EBFCD88

    # Add docker repo
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$OS \
    $(lsb_release -cs) \
    stable"

    # Install docker
    apt_update
    apt-get -y install docker-ce docker-ce-cli containerd.io

    # Make sure docker is enabled
    enable_docker

  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      # Install dependencies for Docker
      yum install -y yum-utils device-mapper-persistent-data lvm2

      # Add repo to yum
      yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

      # Install Docker
      yum install -y docker-ce docker-ce-cli containerd.io
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      # Install dependencies for Docker
      dnf install -y dnf-utils device-mapper-persistent-data lvm2

      # Add repo to dnf
      dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

      # Install Docker
      dnf install -y docker-ce docker-ce-cli containerd.io --nobest
    fi

    enable_docker
  fi

  echo "* O Docker agora está instalado."
}

ptdl_dl() {
  echo "* Instalando Pterodactyl Wings .. "

  mkdir -p /etc/pterodactyl
  curl -L -o /usr/local/bin/wings "$WINGS_DL_URL"

  chmod u+x /usr/local/bin/wings

  echo "* Pronto."
}

systemd_file() {
  echo "* Instalando o serviço systemd..."
  curl -o /etc/systemd/system/wings.service $GITHUB_BASE_URL/configs/wings.service
  systemctl daemon-reload
  systemctl enable wings
  echo "* Serviço systemd instalado!"
}

install_mariadb() {
  case "$OS" in
    ubuntu | debian)
      curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
      apt update && apt install mariadb-server -y
      ;;
    centos)
      [ "$OS_VER_MAJOR" == "7" ] && curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
      [ "$OS_VER_MAJOR" == "7" ] && yum -y install mariadb-server
      [ "$OS_VER_MAJOR" == "8" ] && dnf install -y mariadb mariadb-server
      ;;
  esac

  systemctl enable mariadb
  systemctl start mariadb
}


ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    print_warning "Let's Encrypt requer que a porta 80/443 seja aberta! Você optou por sair da configuração automática do firewall; use isso por sua própria conta e risco (se a porta 80/443 for fechada, o script falhará)!"
  fi

  print_warning "Você não pode usar o Let's Encrypt com seu nome de host como um endereço IP! Deve ser um FQDN (por exemplo, node.example.org)."

  echo -e -n "* Você deseja configurar HTTPS automaticamente usando Let's Encrypt? (Y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi
}

firewall_ufw() {
  apt install ufw -y

  echo -e "\n* Habilitando Firewall Descomplicado (UFW)"
  echo "* Abrindo a porta 22 (SSH), 8080 (Daemon Port), 2022 (Daemon SFTP Port)"

  # pointing to /dev/null silences the command output
  ufw allow ssh > /dev/null
  ufw allow 8080 > /dev/null
  ufw allow 2022 > /dev/null

  [ "$CONFIGURE_LETSENCRYPT" == true ] && ufw allow http > /dev/null
  [ "$CONFIGURE_LETSENCRYPT" == true ] && ufw allow https > /dev/null

  ufw --force enable
  ufw --force reload
  ufw status numbered | sed '/v6/d'
}

firewall_firewalld() {
  echo -e "\n* Enabling firewall_cmd (firewalld)"
  echo "* Abrindo a porta 22 (SSH), 8080 (Daemon Port), 2022 (Daemon SFTP Port)"

  # Install
  [ "$OS_VER_MAJOR" == "7" ] && yum -y -q install firewalld > /dev/null
  [ "$OS_VER_MAJOR" == "8" ] && dnf -y -q install firewalld > /dev/null

  # Enable
  systemctl --now enable firewalld > /dev/null # Enable and start

  # Configure
  firewall-cmd --add-service=ssh --permanent -q # Port 22
  firewall-cmd --add-port 8080/tcp --permanent -q # Port 8080
  firewall-cmd --add-port 2022/tcp --permanent -q # Port 2022
  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall-cmd --add-service=http --permanent -q # Port 80
  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall-cmd --add-service=https --permanent -q # Port 443

  firewall-cmd --permanent --zone=trusted --change-interface=pterodactyl0 -q
  firewall-cmd --zone=trusted --add-masquerade --permanent
  firewall-cmd --reload -q # Enable firewall

  echo "* Firewall-cmd installed"
  print_brake 70
}

letsencrypt() {
  FAILED=false

  # Install certbot
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    apt-get install certbot -y
  elif [ "$OS" == "centos" ]; then
    [ "$OS_VER_MAJOR" == "7" ] && yum install certbot
    [ "$OS_VER_MAJOR" == "8" ] && dnf install certbot
  else
    # exit
    print_error "OS não suportado."
    exit 1
  fi

  # If user has nginx
  systemctl stop nginx || true

  # Obtain certificate
  certbot certonly --no-eff-email --email "$EMAIL" --standalone -d "$FQDN" || FAILED=true

  systemctl start nginx || true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    print_warning "O processo de obtenção de um certificado Let's Encrypt falhou!"
  fi
}

####################
## MAIN FUNCTIONS ##
####################

perform_install() {
  echo "* Instalando pterodactyl wings.."
  [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ] && apt_update
  [ "$OS" == "centos" ] && [ "$OS_VER_MAJOR" == "7" ] && yum_update
  [ "$OS" == "centos" ] && [ "$OS_VER_MAJOR" == "8" ] && dnf_update
  [ "$CONFIGURE_UFW" == true ] && firewall_ufw
  [ "$CONFIGURE_FIREWALL_CMD" == true ] && firewall_firewalld
  install_docker
  ptdl_dl
  systemd_file
  [ "$INSTALL_MARIADB" == true ] && install_mariadb
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  # return true if script has made it this far
  return 0
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/etc/pterodactyl" ]; then
    print_warning "O script detectou que você já tem asas de Pterodáctilo em seu sistema! Você não pode executar o script várias vezes, ele falhará!"
    echo -e -n "* Tem certeza de que deseja continuar? (y/N): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      print_error "Instalação abortada!"
      exit 1
    fi
  fi

  # detect distro
  detect_distro

  print_brake 70
  echo "* Pterodactyl Wings instalação script @ $SCRIPT_RELEASE"
  echo "*"
  echo "* Copyright (C) 2021, KaduPrays, <fabiomegaxd@hotmail.com.br>"
  echo "* https://github.com/kaduprays/pterodactyl-installer"
  echo "*"
  echo "* Este script não está associado ao Projeto Pterodactyl oficial."
  echo "*"
  echo "* Rodando $OS versão $OS_VER."
  echo "* O pterodactyl / wings mais recentes é $WINGS_VERSION"
  print_brake 70

  # checks if the system is compatible with this installation script
  check_os_comp

  echo "* "
  echo "* O instalador irá instalar o Docker, dependências necessárias para o Wings"
  echo "* bem como a própria Wings. Mas ainda é necessário criar o node"
  echo "* no painel e, em seguida, coloque o arquivo de configuração no nó manualmente após"
  echo "* a instalação terminou. Leia mais sobre este processo em dia"
  echo "* Documentação oficial: $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure-daemon')"
  echo "* "
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: este script não iniciará o Wings automaticamente (instalará o serviço systemd, não o iniciará)."
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: este script não habilitará a troca (para docker)."
  print_brake 42

  echo -e "* ${COLOR_RED}Note${COLOR_NC}: Se você instalou o painel Pterodactyl na mesma máquina, não use esta opção ou o script falhará!"
  echo -n "* Você gostaria de instalar o servidor MariaDB (MySQL) no daemon também? (y/N): "

  read -r CONFIRM_INSTALL_MARIADB
  [[ "$CONFIRM_INSTALL_MARIADB" =~ [Yy] ]] && INSTALL_MARIADB=true

  # UFW is available for Ubuntu/Debian
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    echo -e -n "* Quer configurar o UFW (firewall) automaticamente? (y/N): "
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Yy] ]]; then
      CONFIGURE_UFW=true
      CONFIGURE_FIREWALL=true
    fi
  fi

  # Firewall-cmd is available for CentOS
  if [ "$OS" == "centos" ]; then
    echo -e -n "* Você deseja configurar automaticamente o firewall-cmd (firewall)? (y/N) "
    read -r CONFIRM_FIREWALL_CMD

    if [[ "$CONFIRM_FIREWALL_CMD" =~ [Yy] ]]; then
      CONFIGURE_FIREWALL_CMD=true
      CONFIGURE_FIREWALL=true
    fi
  fi

  ask_letsencrypt

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while [ -z "$FQDN" ]; do
        echo -n "* Defina o FQDN a ser usado para Let's Encrypt (node.exemplo.com): "
        read -r FQDN

        ASK=false

        [ -z "$FQDN" ] && print_error "FQDN não pode estar vazio"
        bash <(curl -s $GITHUB_BASE_URL/lib/verify-fqdn.sh) "$FQDN" "$OS" || ASK=true
        [ -d "/etc/letsencrypt/live/$FQDN/" ] && print_error "Já existe um certificado com este FQDN!" && ASK=true

        [ "$ASK" == true ] && FQDN=""
        [ "$ASK" == true ] && echo -e -n "* Você ainda deseja configurar HTTPS automaticamente usando Let's Encrypt? (y/N): "
        [ "$ASK" == true ] && read -r CONFIRM_SSL

        if [[ ! "$CONFIRM_SSL" =~ [Yy] ]] && [ "$ASK" == true ]; then
          CONFIGURE_LETSENCRYPT=false
          FQDN="none"
        fi
    done
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    # set EMAIL
    while [ -z "$EMAIL" ]; do
        echo -n "* Digite o endereço de e-mail para Let's Encrypt: "
        read -r EMAIL

        [ -z "$EMAIL" ] && print_error "Email não pode estar vazio"
    done
  fi

  echo -n "* Continuar com a instalação? (y/N): "

  read -r CONFIRM
  [[ "$CONFIRM" =~ [Yy] ]] && perform_install && return

  print_error "Instalação abortada!"
  exit 0
}

function goodbye {
  echo ""
  print_brake 70
  echo "* Instalação da wings concluída"
  echo "*"
  echo "* Para continuar, você precisa configurar o Wings para funcionar com o seu painel"
  echo "* Consulte o guia oficial, $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure-daemon')"
  echo "* "
  echo "* Você pode copiar o arquivo de configuração do painel manualmente para /etc/pterodactyl/config.yml"
  echo "* ou você pode usar o botão \"implantação automática\" do painel e simplesmente colar o comando neste terminal"
  echo "* "
  echo "* Você pode então iniciar o Wings manualmente para verificar se está funcionando"
  echo "*"
  echo "* sudo wings"
  echo "*"
  echo "* Depois de verificar se ele está funcionando, use CTRL + C e inicie o Wings como um serviço (é executado em segundo plano)"
  echo "*"
  echo "* systemctl start wings"
  echo "*"
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: É recomendado habilitar a troca (para Docker, leia mais sobre isso na documentação oficial)."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: Se você não configurou seu firewall, as portas 8080 e 2022 precisam ser abertas."
  print_brake 70
  echo ""
}

# run script
main
goodbye
