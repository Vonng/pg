#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   setup-ssh.sh
# Mtime     :   2019-03-02
# Desc      :   Setup local ssh access for vagrant vms
# Path      :   bin/setup-ssh.sh
# Author    :   Vonng(fengruohang@outlook.com)
#==============================================================#


# module info
__MODULE_SETUP_SSH="setup-ssh"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: setup_ssh
# Desc: Write ssh config to ~/.ssh/pgtest_config
# Note: Will add Include line to ~/.ssh/config
#--------------------------------------------------------------#
function setup_ssh() {
    if [[ ! -d ${HOME}/.ssh ]]; then
        echo "warn: ${HOME}/.ssh not exist, create"
        mkdir -p ${HOME}/.ssh
    fi

    if [[ ! -f ${HOME}/.ssh/config ]]; then
        touch ${HOME}/.ssh/config
    fi

    if ! $(grep 'Include ~/.ssh/pgtest_config' ${HOME}/.ssh/config > /dev/null 2>&1); then
        echo "info: write 'Include ~/.ssh/pgtest_config' to ${HOME}/.ssh/config"
        echo 'Include ~/.ssh/pgtest_config' >> ${HOME}/.ssh/config
    fi

    local active_node_list=$(vagrant status | grep running | awk '{print $1}' | xargs 2>/dev/null)
    if [[ $? != 0 ]]; then
        echo 'error: get vagrant status failed'
        return 1
    fi

    echo "info: active nodes: ${active_node_list}"
    vagrant ssh-config ${active_node_list} > ${HOME}/.ssh/pgtest_config 2> /dev/null
    if [[ $? != 0 ]]; then
        echo "error: vagrant ssh-config failed"
        return 2
    fi

    setup_vagrant_alias 2> /dev/null

    return 0
}

function setup_vagrant_alias(){
    echo primary standby offline monitor | xargs -n1 -I{} ssh {} "echo \"alias pg='sudo su postgres'\" >> ~/.bash_profile"
    echo primary standby offline monitor | xargs -n1 -I{} ssh {} "echo \"alias root='sudo su'\" >> ~/.bash_profile"
    echo primary standby offline monitor | xargs -n1 -I{} ssh {} "echo \"alias st='sudo systemctl'\" >> ~/.bash_profile"
    echo primary standby offline monitor | xargs -n1 -I{} ssh {} "echo \"alias psql='sudo -iu postgres psql'\" >> ~/.bash_profile"
}



#==============================================================#
#                             Main                             #
#==============================================================#
# Code:
#   0   ok
#   1   vagrant status failed
#   2   vagrant ssh-config failed
#==============================================================#
setup_ssh
setup_vagrant_alias