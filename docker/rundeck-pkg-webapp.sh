#!/bin/bash

OPBDOCKER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OPBROOT="${OPBDOCKER}/.."

cd ${OPBDOCKER} || exit 1

. ${OPBROOT}/environment.sh

echo "OM 3 WEBAPP PKG"
#echo "$@"
echo "---------------"

[[ -z $NAME ]] && {
	echo "$0: variable NAME is not defined"
	exit 1
}

LREPO=${REPOS[$NAME]}
if [ -n "${TARGETREPOENV:-}" ] ; then
	echo "variable TARGETREPOENV is set to ${TARGETREPOENV}"
	LREPO=$(echo $LREPO|sed -e "s@dev-@${TARGETREPOENV}-@")
	echo "variable LREPO now points to ${LREPO}"
fi

if [ -n "${RELEASE_NAME:-}" ] ; then
    [ "${PRERELEASE:-}" = true ] && LREPO=uat${LREPO#dev} || LREPO=prod${LREPO#dev}
fi

echo "$0 starting..."
echo "NAME=$NAME"
echo "CODE=$CODE"
echo "LREPO=$LREPO"
echo

[[ -z $LREPO ]] && {
	echo "$0: package repository LREPO is not defined"
	exit 1
}

# the webapp package embeds the index.html asset of an om3-webapp github release
[[ -z $CODE ]] && {
	echo "$0: variable CODE must be an om3-webapp release tag"
	exit 1
}
# the om3-webapp github workflow attaches index.html to the release a few
# minutes after its publication, which triggers this job: wait for it
FETCH_TIMEOUT=1800
FETCH_INTERVAL=30
WAITED=0
while ! ${OPBROOT}/tools/fetch_release.sh opensvc om3-webapp "${CODE}" index.html
do
	if [ $WAITED -ge $FETCH_TIMEOUT ] ; then
		echo "$0: unable to fetch om3-webapp release ${CODE} index.html after ${WAITED}s"
		exit 1
	fi
	echo "index.html not attached to release ${CODE} yet, retrying in ${FETCH_INTERVAL}s"
	sleep $FETCH_INTERVAL
	WAITED=$((WAITED + FETCH_INTERVAL))
done

# the webapp packages are distro independent: one deb (built on debian12) and
# one noarch rpm (built on rhel9), published as is in every repository of
# their family. NAME only selects the family. The jobs of the other distros
# reuse the packages built for the same CODE.
case $NAME in
rhel*|sles*)
	PKGFAMILY=rpm-noarch
	IMAGE=rhel9:pkgbuild
	;;
u2*|debian*)
	PKGFAMILY=deb-noarch
	IMAGE=debian12:pkgbuild
	;;
*)
	echo "$0: unsupported distro: $NAME"
	exit 1
	;;
esac
# package revision (deb revision, rpm release), 1 unless a packaging fix
# needs to republish a webapp version
PKGREV=${PKGREV:-1}
[[ $PKGREV =~ ^[1-9][0-9]*$ ]] || {
	echo "$0: PKGREV must be a positive integer, got '${PKGREV}'"
	exit 1
}
echo "PKGREV=$PKGREV"

OUTDIR=${OPBROOT}/tools/webapp-out/${PKGFAMILY}
BUILDID="CODE=${CODE} RELEASE_NAME=${RELEASE_NAME:-} PRERELEASE=${PRERELEASE:-} PKGREV=${PKGREV}"
# outside OUTDIR, which the build container recreates as root
BUILDIDFILE=${OPBROOT}/tools/webapp-out/.${PKGFAMILY}.buildid

# rundeck runs the distro jobs in parallel: one build per family at a time
mkdir -p ${OPBROOT}/tools/webapp-out
exec 8>"${OPBROOT}/tools/webapp-out/.${PKGFAMILY}.lock"
flock -w 1800 8 || {
	echo "$0: timeout waiting for the ${PKGFAMILY} build lock"
	exit 1
}

if [ "$(cat ${BUILDIDFILE} 2>/dev/null)" = "${BUILDID}" ] ; then
	echo "${PKGFAMILY} packages already built for ${BUILDID}:"
	ls -l ${OUTDIR}
	exit 0
fi

rm -f ${BUILDIDFILE}
TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
echo "${TIMESTAMP} NAME=${NAME} docker run -e OSVCWEBAPP=true -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${PKGFAMILY} -e OSVCREPO=all -e OSVC_PKGREV=${PKGREV} -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools -v ${HOME}/.cache:/cache --rm ${IMAGE} om3-webapp-build" >> $0.log

docker run -e OSVCWEBAPP=true -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${PKGFAMILY} -e OSVCREPO=all -e OSVC_PKGREV=${PKGREV} -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools -v ${HOME}/.cache:/cache --rm ${IMAGE} om3-webapp-build || {
    echo "$0: error while trying to build webapp package"
    exit 1
}
echo "${BUILDID}" > ${BUILDIDFILE}
