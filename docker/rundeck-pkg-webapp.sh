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
${OPBROOT}/tools/fetch_release.sh opensvc om3-webapp "${CODE}" index.html || {
	echo "$0: unable to fetch om3-webapp release ${CODE} index.html"
	exit 1
}

TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
echo "${TIMESTAMP} docker run -e OSVCWEBAPP=true -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${NAME} -e OSVCREPO=$LREPO -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools -v ${HOME}/.cache:/cache --rm $NAME:pkgbuild om3-webapp-build" >> $0.log

docker run -e OSVCWEBAPP=true -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${NAME} -e OSVCREPO=$LREPO -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools -v ${HOME}/.cache:/cache --rm $NAME:pkgbuild om3-webapp-build || {
    echo "$0: error while trying to build webapp package"
    exit 1
}
