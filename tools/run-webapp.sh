#!/bin/bash

set -au

ROOTSCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOTSCRIPTS || exit 1

. ./common.sh

# output directory for packages
OUTDIR=webapp-out
[[ ! -d $ROOTSCRIPTS/$OUTDIR ]] && {
    mkdir -p $ROOTSCRIPTS/$OUTDIR
    chown builder:builder $ROOTSCRIPTS/$OUTDIR
}

TEMPDIR=webapp-tmp
mkdir -p $ROOTSCRIPTS/$TEMPDIR
chown builder:builder $ROOTSCRIPTS/$TEMPDIR

grep -qEi "red hat|redhat|suse" /etc/os-release && {
    title "$0: RPM BUILD"
        . $ROOTSCRIPTS/build-webapp-rpm.sh || {
        echo "$0: error during rpm build"
        exit 1
    }
}

grep -qEi "debian|ubuntu" /etc/os-release && {
    title "$0: DEB BUILD"
        . $ROOTSCRIPTS/build-webapp-deb.sh || {
        echo "$0: error during deb build"
        exit 1
    }
}

exit 0
