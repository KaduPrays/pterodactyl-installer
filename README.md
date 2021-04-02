# :bird: Instalador pterodactyl
[![Discord](https://img.shields.io/discord/682342331206074373?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.gg/tuyJhrzs)

Script realizado por KaduPrays#4208 - Qual quer duvida veja no site oficial!

Leia mais sobre [Pterodactyl] (https://pterodactyl.io/) aqui. Este script não está associado ao Projeto Pterodactyl oficial

## Features

- Instalação automática do Painel Pterodactyl (dependências, banco de dados, cronjob, nginx).
- Instalação automática das asas de pterodáctilo (Docker, systemd).
- Painel: (opcional) configuração automática do Let's Encrypt.
- Painel: (opcional) configuração automática do UFW (firewall para Ubuntu / Debian).

## Ajuda e suporte

Para obter ajuda e suporte em relação ao script em si e **não ao projeto Pterodactyl oficial**, você pode se juntar ao [Grupo do discord](https://discord.gg/tuyJhrzs).

## Instalações com suporte

Lista de configurações de instalação suportadas para painel e asas (instalações suportadas por este script de instalação).

### Supported panel operating systems and webservers

| Sistema operacional |  Versão | suporte nginx	     | Versão do php |
| ------------------- | ------- | ------------------ | ------------- |
| Ubuntu              | 14.04   | :red_circle:       |               |
|                     | 16.04   | :red_circle: \*    |               |
|                     | 18.04   | :white_check_mark: | 8.0           |
|                     | 20.04   | :white_check_mark: | 8.0           |
| Debian              | 8       | :red_circle: \*    |               |
|                     | 9       | :white_check_mark: | 8.0           |
|                     | 10      | :white_check_mark: | 8.0           |
| CentOS              | 6       | :red_circle:       |               |
|                     | 7       | :white_check_mark: | 8.0           |
|                     | 8       | :white_check_mark: | 8.0           |


_\* Ubuntu 16 e Debian 8 não são mais suportados, pois Pterodactyl não o suporta ativamente._

## Usando o script para instalação

Para usar os scripts de instalação, basta executar este comando como root. 
O script perguntará se você gostaria de instalar apenas o painel, apenas o daemon ou ambos.

```bash
bash <(curl -s https://pterodactyl.kaduprays.com)
```

_Nota: Em alguns sistemas, é necessário já estar logado como root antes de executar o comando de uma linha (onde sudo não frente do comando não funciona)._

## Configuração de firewall

Os scripts de instalação podem instalar e configurar um firewall para você. O script perguntará se você quer isso ou não. É altamente recomendável optar pela configuração automática do firewall.


## Contribuidores ✨

Copyright (C) 2021, KaduPrays, <pterodactyl@kaduprays.com>

Desenvolvedor do codigo [KaduPrays](https://github.com/kaduprays).

