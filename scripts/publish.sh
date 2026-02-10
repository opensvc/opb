#!/bin/bash
#
#
set -a
set -x 
opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."
pkgroot="${opbroot}/tools/out"

. ${opbroot}/environment.sh

QANAME=$1

echo "$0 starting..."

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
	          ssh -q repoadm "/usr/bin/test -f /data/rpm/$LREPO/$PKGARCH/$RPM && exit 0 || exit 1" && {
		      echo "file $RPM already present in $LREPO. skipping publication"
		      exit 0
		  }
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
	# for logging purposes
        for manifest in $(ls -1 *.$QANAME)
        do
            cat $manifest ; . $manifest
        done
	ssh -q repoadm "find /data/apt/$flavor/pool -type f" > /tmp/pool.$flavor.list
	cat /tmp/pool.$flavor.list | grep "$PATTERN" > /tmp/pool.$flavor.list.filtered
	if [ -s /tmp/pool.$flavor.list.filtered ]; then
	    # found some entries in the pool
	    # need to present found entries into repo
	    echo "Found files matching pattern $PATTERN in /data/apt/$flavor/pool"
	    cat /tmp/pool.$flavor.list.filtered
	    echo
	    for file in $(cat /tmp/pool.$flavor.list.filtered | grep -E '.deb$|.dsc$')
	    do
                action="${file##*.}"
		echo "Adding $file to $LREPO"
		echo "reprepro -b /data/apt/$flavor include$action $LREPO $file"
		ssh -q repoadm "reprepro -b /data/apt/$flavor include$action $LREPO $file"
	    done
	else
	    # pattern is not present in pool
	    # need to upload files to repo
	    scp -q * repoadm:/data/apt/$flavor/incoming/in_$LREPO/
	    ssh -q repoadm "ls -l /data/apt/$flavor/incoming/in_$LREPO/ ; reprepro -b /data/apt/$flavor processincoming in_$LREPO" || exit 1
	    ssh -q repoadm "ls -1 /data/apt/$flavor/incoming/in_$LREPO && rm -f /data/apt/$flavor/incoming/in_$LREPO/*"
	fi

	#ssh -q repoadm "( find /data/apt/$flavor/pool -type f -name $DEB 2>/dev/null | grep -q . ) && exit 0 || exit 1" && {
	#      echo "file $DEB already present in $LREPO. skipping publication"
	#      exit 0
        #}
        #scp -q * repoadm:/data/apt/$flavor/incoming/in_$LREPO/
        #ssh -q repoadm "ls -l /data/apt/$flavor/incoming/in_$LREPO/ ; reprepro -b /data/apt/$flavor processincoming in_$LREPO" || exit 1
	#ssh -q repoadm "ls -1 /data/apt/$flavor/incoming/in_$LREPO && rm -f /data/apt/$flavor/incoming/in_$LREPO/*"
        exit 0
    }
    exit 1
}

case $1 in
rhel7|rhel8|rhel9|rhel10|sles15)
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
