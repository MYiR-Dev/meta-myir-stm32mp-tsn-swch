#!/bin/bash

set -eu -o pipefail

shopt -s failglob

: ${SYSREPOCTL:=sysrepoctl}
: ${SYSREPOCFG:=sysrepocfg}
: ${SYSREPOCTL_ROOT_PERMS:=-o root:root -p 600}
: ${STOCK_CONFIG:=/usr/share/netopeer2-server/stock_config.xml}
: ${YANG_DIR:=/etc/sysrepo/yang/}

is_yang_module_installed() {
    module=$1

    $SYSREPOCTL -l | grep --count "^$module [^|]*|[^|]*| Installed .*$" > /dev/null
}

install_yang_module() {
    module=$1

    if ! is_yang_module_installed $module; then
        echo "- Installing module $module..."
        $SYSREPOCTL -i -g ${YANG_DIR}/$module.yang $SYSREPOCTL_ROOT_PERMS
    else
        echo "- Module $module already installed."
    fi
}

enable_yang_module_feature() {
    module=$1
    feature=$2

    if ! $SYSREPOCTL -l | grep --count "^$module [^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|.* $feature.*$" > /dev/null; then
        echo "- Enabling feature $feature in $module..."
        $SYSREPOCTL -m $module -e $feature
    else
        echo "- Feature $feature in $module already enabled."
    fi
}

install_yang_module ietf-netconf
for f in writable-running candidate rollback-on-error validate startup xpath url; do
    enable_yang_module_feature ietf-netconf $f
done

install_yang_module ietf-netconf-with-defaults
install_yang_module ietf-netconf-monitoring
install_yang_module notifications
install_yang_module nc-notifications
install_yang_module ietf-netconf-notifications
install_yang_module ietf-yang-library

if ! is_yang_module_installed ietf-keystore; then
    echo "- Module ietf-keystore not installed, skipping configuration models installation."
    exit 0
fi

install_yang_module ietf-netconf-server
for f in listen ssh-listen tls-listen call-home ssh-call-home tls-call-home; do
    enable_yang_module_feature ietf-netconf-server $f
done

install_yang_module ietf-system
for f in authentication local-users; do
    enable_yang_module_feature ietf-system $f
done

if [ -n "$($SYSREPOCFG -d startup -f xml --export ietf-netconf-server)" ]; then
    exit 0
fi

$SYSREPOCFG -d startup -i $STOCK_CONFIG ietf-netconf-server
