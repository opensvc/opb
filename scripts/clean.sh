#!/bin/bash
#
opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."

. ${opbroot}/environment.sh

QANAME=$1

[[ -z ${QANAME} ]] && {
    echo "Please give target distribution as argument"
    exit 1
}

LREPO=${REPOS[$QANAME]}
if [ -n "${RELEASE_NAME:-}" ] ; then
    [ "${PRERELEASE:-}" = true ] && LREPO=uat${LREPO#dev} || LREPO=prod${LREPO#dev}
fi

echo "QANAME=$QANAME"
echo "LREPO=$LREPO"
echo

[[ -z $LREPO ]] && {
	echo "$0: package repository LREPO is not defined"
	exit 1
}

if [ -n "${RELEASE_NAME:-}" ] ; then
    echo "$0: package repository LREPO skipped on RELEASE_NAME=${RELEASE_NAME:-}"
    exit 0
fi

case $1 in
rhel7|rhel8|rhel9|sles15)
        echo "Cleanup repo $QANAME - $LREPO"
	for arch in $(ssh -q repoadm "cd /data/rpm/$LREPO && ls -1")
	do
            ssh -q repoadm "rm -rf /data/rpm/$LREPO/$arch/* && createrepo_c /data/rpm/$LREPO/$arch"	
	done
        ;;
u2004|u2204|u2404)
        echo "Cleanup repo $QANAME - $LREPO"
	PKG=$(ssh -q repoadm "reprepro -b /data/apt/ubuntu list $LREPO | awk -v ORS=' ' '{print \$2}'")
	[[ ! -z $PKG ]] && ssh -q repoadm "for p in $PKG; do reprepro -b /data/apt/ubuntu remove $LREPO \$p || /bin/false; done;"
	exit 0
        ;;
debian*)
        echo "Cleanup repo $QANAME - $LREPO"
	set -x
	PKG=$(ssh -q repoadm "reprepro -b /data/apt/debian list $LREPO | awk -v ORS=' ' '{print \$2}'")
	[[ ! -z $PKG ]] && ssh -q repoadm "for p in $PKG; do reprepro -b /data/apt/debian remove $LREPO \$p || /bin/false; done;"
	exit 0
        ;;
*)
        echo "unsupported distro: $1" >&2
        exit 1
        ;;
esac
