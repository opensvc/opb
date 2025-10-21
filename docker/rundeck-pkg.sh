#!/bin/bash

OPBDOCKER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OPBROOT="${OPBDOCKER}/.."

cd ${OPBDOCKER} || exit 1

. ${OPBROOT}/environment.sh

[[ -z $NAME ]] && {
	echo "$0: variable NAME is not defined"
	exit 1
}

LREPO=${REPOS[$NAME]}
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

TIMESTAMP=$(date --utc +%Y%m%d%H%M%S)
echo "${TIMESTAMP} docker run -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${NAME} -e OSVCREPO=$LREPO -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools --rm $NAME:pkgbuild build" >> $0.log

docker run -e OSVC_CODE_TO_BUILD=${CODE} -e OSVCDIST=${NAME} -e OSVCREPO=$LREPO -e OSVC_RELEASE_NAME=${RELEASE_NAME} -e OSVC_PRERELEASE=${PRERELEASE} -v ${OPBROOT}/tools:/tools --rm $NAME:pkgbuild build || {
    echo "$0: error while trying to build package"
    exit 1
}
