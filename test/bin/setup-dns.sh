#!/bin/bash
set -uo pipefail

#==============================================================#
# File      :   setup-dns.sh
# Mtime     :   2019-03-02
# Desc      :   Setup DNS for pg testing env
# Path      :   bin/setup-dns.sh
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as root
#==============================================================#


# module info
__MODULE_SETUP_DNS="setup-dns"

PROG_DIR="$(cd $(dirname $0) && pwd)"
PROG_NAME="$(basename $0)"


#--------------------------------------------------------------#
# Name: setup_dns
# Desc: Write pgtest DNS entries to /etc/hosts
# Note: Run this in localhost and virtual machines
#--------------------------------------------------------------#
function setup_dns() {
   if [[ $(whoami) != "root" ]]; then
      echo "error: setup-dns.sh require root privilege"
      return 1
   fi

   if $(grep 'pgtest dns entries' /etc/hosts > /dev/null 2>&1); then
      echo "warn: dns already set in /etc/hosts, skip"
      return 0
   fi

	cat >> /etc/hosts <<- EOF
	# pgtest dns entries
	10.10.10.10   test001m01
	10.10.10.10   n1
	10.10.10.10   primary
	10.10.10.10   primary.test
	10.10.10.10   primary.test.pg

	10.10.10.11   test001s01
	10.10.10.11   n2
	10.10.10.11   standby
	10.10.10.11   standby.test
	10.10.10.11   standby.test.pg

	10.10.10.12   test001o01
	10.10.10.12   n3
	10.10.10.12   offline
	10.10.10.12   offline.test
	10.10.10.12   offline.test.pg

	10.10.10.13   meta001m01
	10.10.10.13   n4
	10.10.10.13   meta
	10.10.10.13   primary.meta
	10.10.10.13   primary.meta.pg
	10.10.10.13   monitor
	EOF

   if [[ $? != 0 ]]; then
      echo "error: write dns record failed"
      return 2
   fi

   return 0
}



#==============================================================#
#                             Main                             #
#==============================================================#
# Code:
#   0   ok
#   1   insufficient privilege
#   2   write DNS record to /etc/hosts failed
#==============================================================#
setup_dns
