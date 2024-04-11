#!/bin/bash

set -au

ROOTSCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOTSCRIPTS || exit 1

. ./common.sh

# output directory for packages
[[ ! -d $ROOTSCRIPTS/out ]] && {
    mkdir -p $ROOTSCRIPTS/out
    chown builder:builder $ROOTSCRIPTS/out
}

mkdir -p $ROOTSCRIPTS/tmp 
chown builder:builder $ROOTSCRIPTS/tmp

grep -qEi "red hat|redhat|suse" /etc/os-release && {
    title "RPM BUILD"
    . /etc/profile.d/golang.sh && . $ROOTSCRIPTS/build-rpm.sh || {
        echo "error during rpm build"
        exit 1
    }
}

grep -qEi "debian|ubuntu" /etc/os-release && {
    title "DEB BUILD"
    . /etc/profile.d/golang.sh && . $ROOTSCRIPTS/build-deb.sh || {
        echo "error during deb build"
        exit 1
    }
}

exit 0
