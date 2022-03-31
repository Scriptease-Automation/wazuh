#!/bin/bash
while getopts d: name
do
    case "${name}" in
        d) domain=${OPTARG};;
        *) echo "Invalid option: -$name" ;;
    esac
done

curl -so ~/unattended-installation.sh https://packages.wazuh.com/resources/4.2/open-distro/unattended-installation/unattended-installation.sh && bash ~/unattended-installation.sh
curl -so ~/configuration.sh https://mirror.istc.am/scripts/wazuh/wazuh/configuration.sh && bash ~/configuration.sh -d $domain