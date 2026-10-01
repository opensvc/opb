#!/bin/bash
#
opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."

. ${opbroot}/environment.sh
set -x
QANAME=$1

env

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

# one publish/clean at a time: aptly takes an exclusive lock on its leveldb
# database and parallel rundeck jobs made remote aptly commands fail.
# task#prune of the pkgmgr service takes the same lock.
exec 9>"${opbroot}/.aptly.lock"
flock -w 1800 9 || {
    echo "$0: timeout waiting for ${opbroot}/.aptly.lock"
    exit 1
}


function cleanup_aptly_repo
{
	local repo=$1
	local flavor=$2
	psnap=$(get_published_snapshot $repo)
	if [ -n "$psnap" ]; then
            echo $psnap | grep -q '^empty' || {
            echo "Removing published $psnap from $LREPO apt/$flavor"
	    ssh -q repoadmv2 "aptly publish drop $LREPO apt/$flavor && aptly publish snapshot -architectures="amd64" -distribution="$LREPO" empty-$LREPO apt/$flavor"
            }
	fi
	# remove snapshots except empty one
	for snap in $(ssh -q repoadmv2 "aptly snapshot list -raw" | grep "$repo" | grep -v empty)
	do
	    echo "Removing snap $snap"
	    ssh -q repoadmv2 "aptly snapshot drop $snap"
	done
	# remove packages from repo
	for pkg in $(ssh -q repoadmv2 "aptly repo show -with-packages $repo" | awk '/Packages:/,/^$/ {if ($0 ~ /^[[:space:]]+[^[:space:]]/ && !/^$/ && !/Packages:/) print $1}')
	do
		echo "Removing package $pkg from $repo"
		ssh -q repoadmv2 "aptly repo remove $repo $pkg"
	done
	echo "Cleaning aptly database and pool filesystem"
	ssh -q repoadmv2 "aptly db cleanup"
}

case $QANAME in
rhel7|rhel8|rhel9|rhel10|sles15|sles16)
        echo "Cleanup repo $QANAME - $LREPO"
#	for arch in $(ssh -q repoadm "cd /data/rpm/$LREPO && ls -1")
#	do
#	    OPTS=""
#	    [[ $QANAME == "rhel7" ]] && OPTS="--compatibility"
#            ssh -q repoadm "rm -rf /data/rpm/$LREPO/$arch/* && createrepo_c $OPTS /data/rpm/$LREPO/$arch"
#	done
        for arch in $(ssh -q repoadmv2 "cd /data/rpm/$LREPO && ls -1")
        do
            OPTS=""
            [[ $QANAME == "rhel7" ]] && OPTS="--compatibility"
            ssh -q repoadmv2 "rm -rf /data/rpm/$LREPO/$arch/* && createrepo_c $OPTS /data/rpm/$LREPO/$arch"
        done
        ;;
u2004|u2204|u2404|u2604)
        echo "Cleanup repo $QANAME - $LREPO"
#	PKG=$(ssh -q repoadm "reprepro -b /data/apt/ubuntu list $LREPO | awk -v ORS=' ' '{print \$2}'")
#	[[ ! -z $PKG ]] && ssh -q repoadm "for p in $PKG; do reprepro -b /data/apt/ubuntu remove $LREPO \$p || /bin/false; done;"
	cleanup_aptly_repo $LREPO ubuntu
	exit 0
        ;;
debian*)
        echo "Cleanup repo $QANAME - $LREPO"
#	PKG=$(ssh -q repoadm "reprepro -b /data/apt/debian list $LREPO | awk -v ORS=' ' '{print \$2}'")
#	[[ ! -z $PKG ]] && ssh -q repoadm "for p in $PKG; do reprepro -b /data/apt/debian remove $LREPO \$p || /bin/false; done;"
	cleanup_aptly_repo $LREPO debian
	exit 0
        ;;
*)
        echo "unsupported distro: $1" >&2
        exit 1
        ;;
esac
