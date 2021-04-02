#!/bin/bash

output() {
    echo "- $1"
}

output "Reverter alterações após o lançamento"

# install-panel.sh
sed -i "s/.*GITHUB_SOURCE=.*/GITHUB_SOURCE=\"master\"/" install-panel.sh
sed -i "s/.*SCRIPT_RELEASE=.*/SCRIPT_RELEASE=\"canary\"/" install-panel.sh

# install-wings.sh
sed -i "s/.*GITHUB_SOURCE=.*/GITHUB_SOURCE=\"master\"/" install-wings.sh
sed -i "s/.*SCRIPT_RELEASE=.*/SCRIPT_RELEASE=\"canary\"/" install-wings.sh

output "Confirmar as alterações"

git add .
git commit -S -m "Definir versão para desenvolvimento"
git push

output "Alterações relevantes revertidas"
