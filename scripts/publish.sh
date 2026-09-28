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
if [ -n "${TARGETREPOENV:-}" ] ; then
        echo "variable TARGETREPOENV is set to ${TARGETREPOENV}"
        LREPO=$(echo $LREPO|sed -e "s@dev-@${TARGETREPOENV}-@")
        echo "variable LREPO now points to ${LREPO}"
fi

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
    }
}

function publish_rpm_v2()
{
    cd $pkgroot/$QANAME && {
        for manifest in $(ls -1 *.$QANAME)
        do
            ( . $manifest;
              [[ $PKGARCH != 'source' ]] && {
                  cat $manifest
                  ssh -q repoadmv2 "/usr/bin/test -f /data/rpm/$LREPO/$PKGARCH/$RPM && exit 0 || exit 1" && {
                      echo "file $RPM already present in $LREPO. skipping publication"
                      exit 0
                  }
                  scp -q $RPM repoadmv2:/data/rpm/$LREPO/$PKGARCH/
                  OPTS=""
                  [[ $QANAME == "rhel7" ]] && OPTS="--compatibility"
                  ssh -q repoadmv2 "createrepo_c $OPTS --update /data/rpm/$LREPO/$PKGARCH"
                  ssh -q repoadmv2 "gpg --yes -a --detach-sign --default-key \$GNUPGKEYID /data/rpm/$LREPO/$PKGARCH/repodata/repomd.xml"
              }
            )
        done
    }
}

function resolve_published_snap
{
	local repo=$1
	local flavor=$2
	ssh -q repoadmv2 "aptly publish show -json $repo apt/$flavor | jq -r '.Sources[0].Name'"
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
    }
}

function get_package_list()
{
    echo 
}

function publish_apt_v2()
{
    local flavor=$1
    cd $pkgroot/$QANAME && {
        # for logging purposes
        for manifest in $(ls -1 *.$QANAME)
        do
            cat $manifest ; . $manifest
        done
        ssh -q repoadmv2 "find /data/aptly/public/apt/$flavor/pool -type f" > /tmp/pool.$flavor.list
        cat /tmp/pool.$flavor.list | grep "$PATTERN" > /tmp/pool.$flavor.list.filtered
        if [ -s /tmp/pool.$flavor.list.filtered ]; then
            # found some entries in the pool
            # need to present found entries into repo
            echo "Found files matching pattern $PATTERN in /data/aptly/public/apt/$flavor/pool"
            cat /tmp/pool.$flavor.list.filtered
            echo
	    #[[ $vech = B* ]] &&
            #for file in $(cat /tmp/pool.$flavor.list.filtered | grep -E '.deb$|.dsc$')
            #do
            #    action="${file##*.}"
            #    echo "Adding $file to $LREPO"
            #    echo "reprepro -b /data/apt/$flavor include$action $LREPO $file"
            #    ssh -q repoadm "reprepro -b /data/apt/$flavor include$action $LREPO $file"
            #done
	    echo "2DO 2DO 2DO"
	    # pour chaque entree:
	    #   build liste repo des publications pour ce package
	    #   pour chaque repo:
	    #     retirer/ajouter/publier
	    exit 1
        else
            # pattern is not present in pool
            # need to upload files to repo
	    ssh -q repoadmv2 "mkdir -p /data/tmp/$LREPO"
            scp -q * repoadmv2:/data/tmp/$LREPO/
            ssh -q repoadmv2 "ls -l /data/tmp/$LREPO/"
	    for file in $(ssh -q repoadmv2 "ls -1 /data/tmp/$LREPO" | grep -E ".deb$|.dsc$")
	    do
		echo "Adding $file to $LREPO"
	        ssh -q repoadmv2 "aptly repo add $LREPO /data/tmp/$LREPO/$file"
	    done
	    TS=$(date --utc +%Y%m%d%H%M%SZ)
	    ssh -q repoadmv2 "aptly snapshot create $TS-$LREPO from repo $LREPO" 
	    # ca marche mais c'est pas top, un peu violent
	    # aptly publish switch -force-overwrite dev-opensvc-v3-bookworm apt/debian 20260212083956Z-dev-opensvc-v3-bookworm
	    # 
	    before_snap=$(resolve_published_snap $LREPO $flavor)
	    if [ -n "$before_snap" ]; then
	        echo "before: snap $before_snap is published to $LREPO apt/$flavor"
	        ssh -q repoadmv2 "aptly publish drop $LREPO apt/$flavor"
	    fi
	    ssh -q repoadmv2 "aptly publish snapshot -distribution="$LREPO" $TS-$LREPO apt/$flavor"
	    after_snap=$(resolve_published_snap $LREPO $flavor)
	    echo "after: snap $after_snap is published to $LREPO apt/$flavor"
            ssh -q repoadmv2 "rm -rf /data/tmp/$LREPO"
        fi
    }
}


case $1 in
rhel7|rhel8|rhel9|rhel10|sles15|sles16)
#        publish_rpm
        publish_rpm_v2
        ;;
u2004|u2204|u2404|u2604)
#	publish_apt ubuntu
	publish_apt_v2 ubuntu
        ;;
debian*)
#	publish_apt debian
	publish_apt_v2 debian
        ;;
*)
        echo "unsupported distro: $1" >&2
        exit 1
        ;;
esac
