#!/bin/bash
#
opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."
pkgroot="${opbroot}/tools/out"

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

function publish_rpm()
{
    cd $pkgroot/$QANAME && {
        for manifest in $(ls -1 *.$QANAME)
	do
	    ( . $manifest;
	      [[ $PKGARCH != 'source' ]] && {
                  cat $manifest
	          scp -q $RPM repoadm:/data/rpm/$LREPO/$PKGARCH/
		  OPTS=""
		  [[ $QANAME == "rhel7" ]] && OPTS="--compatibility"
		  ssh -q repoadm "createrepo_c $OPTS --update /data/rpm/$LREPO/$PKGARCH"
		  ssh -q repoadm "gpg --yes -a --detach-sign --default-key \$GNUPGKEYID /data/rpm/$LREPO/$PKGARCH/repodata/repomd.xml"
	      }
            )
        done	    
	exit 0
    }
    exit 1
}

function publish_apt()
{
    local flavor=$1
    cd $pkgroot/$QANAME && {
        for manifest in $(ls -1 *.$QANAME)
        do
            cat $manifest
        done
        scp -q * repoadm:/data/apt/$flavor/incoming/in_$LREPO/
        ssh -q repoadm "ls -l /data/apt/$flavor/incoming/in_$LREPO/ ; reprepro -b /data/apt/$flavor processincoming in_$LREPO" || exit 1
	ssh -q repoadm "ls -1 /data/apt/$flavor/incoming/in_$LREPO && rm -f /data/apt/$flavor/incoming/in_$LREPO/*"
        exit 0
    }
    exit 1
}

case $1 in
rhel7|rhel8|rhel9|sles15)
        publish_rpm
        ;;
u2004|u2204|u2404)
	publish_apt ubuntu
        ;;
debian*)
	publish_apt debian
        ;;
*)
        echo "unsupported distro: $1" >&2
        exit 1
        ;;
esac
