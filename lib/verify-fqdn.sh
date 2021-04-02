#!/bin/bash

set -e

CHECKIP_URL="https://checkip.pterodactyl-installer.se"
DNS_SERVER="8.8.8.8"

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

output() {
   echo "* $1"
}

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

fail() {
  output "The DNS record ($dns_record) does not match your server IP. Please make sure the FQDN $fqdn is pointing to the IP of your server, $ip"
  output "If you are using Cloudflare, please disable the proxy or opt out from Let's Ecnrypt."

  echo -n "* Proceed anyways (your install will be broken if you do not know what you are doing)? (y/N): "
  read -r override

  [[ ! "$override" =~ [Yy] ]] && error "Invalid FQDN or DNS record" && exit 1
  return 0
}

dep_install() {
  [ "$os" == "centos" ] && yum install -q -y bind-utils
  [ "$os" == "debian" ] && apt-get install -y dnsutils -qq
  [ "$os" == "ubuntu" ] && apt-get install -y dnsutils -qq
  return 0
}

confirm() {
  output "This script will perform a HTTPS request to the endpoint $CHECKIP_URL"
  output "The official check-IP service for this script, https://checkip.pterodactyl-installer.se"
  output "- will not log or share any IP-information with any third-party."
  output "If you would like to use another service, feel free to modify the script."

  echo -e -n "* I agree that this HTTPS request is performed (y/N): "
  read -r confirm
  [[ "$confirm" =~ [Yy] ]] || (error "User did not agree" && exit 1)
}

dns_verify() {
  output "Resolving DNS for $fqdn"
  ip=$(curl -4 -s $CHECKIP_URL)
  dns_record=$(dig +short @$DNS_SERVER "$fqdn")
  [ "${ip}" != "${dns_record}" ] && fail
  output "DNS verified!"
}

main() {
  fqdn="$1"
  os="$2"
  dep_install
  confirm
  dns_verify
}

main "$1" "$2"
