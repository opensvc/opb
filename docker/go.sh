#!/usr/bin/env bash

set -au

OPBDOCKER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OPBROOT="${OPBDOCKER}/.."

cd ${OPBDOCKER} || exit 1

. ${OPBDOCKER}/credentials.txt

. ${OPBROOT}/environment.sh

echo '------------------------------------'
echo "command: $0 $@"
echo '------------------------------------'

OSVC_GITREPO_URL="${OSVC_GITREPO_URL:-https://github.com/opensvc/om3.git}"
OSVC_GOLANG_URL="${OSVC_GOLANG_URL:-https://go.dev/dl/go1.23.7.linux-amd64.tar.gz}"
REDHAT_ORG_ID="${REDHAT_ORG_ID:-1234567}"
REDHAT_ACT_KEY="${REDHAT_ACT_KEY:-my_secret_activation_key}"

BUILDIMG=""
DELIMG=""
INTERACTIVE=""
PACKAGE=""
ECHO="echo"
OSVC_CODE_TO_BUILD=""
OSVC_DISTRO=""

function title()
{
    local TITLE="$@"
    echo
    echo "## ${TITLE} ##"
}

function isdistro()
{
    local CANDIDATE="$@"
    for DIST in ${DISTROS[@]}
    do
	    [[ ${DIST} == ${CANDIDATE} ]] && return 0
    done
    echo -e "\nerror: ${CANDIDATE} is not a supported distribution. skipping.\n"
    return 1
}

function cmds()
{
    local D=$1
    local LABEL="$D:pkgbuild"
    local COMMON_OPTS="--pull --network host --no-cache"
    local BUILDARG_OPTS="--build-arg OSVC_GITREPO_URL=$OSVC_GITREPO_URL --build-arg OSVC_GOLANG_URL=$OSVC_GOLANG_URL"
    local REDHAT_OPTS="--build-arg RH_ORG_ID=$REDHAT_ORG_ID --build-arg RH_ACT_KEY=$REDHAT_ACT_KEY"
    local DOCKER_OPTS="$COMMON_OPTS $BUILDARG_OPTS"
    local LREPO=${REPOS[$D]}
    local GITCONFIG=""
    echo $D | grep -q rhel && DOCKER_OPTS="$DOCKER_OPTS $REDHAT_OPTS"
    [[ $BUILDIMG = true ]] && {
	    $ECHO docker buildx build $DOCKER_OPTS -f Dockerfile.$D -t $LABEL . || return 1
    }
    [[ $DELIMG = true ]] && {
	    $ECHO docker rmi -f $LABEL || return 1
    }
    [[ $PACKAGE = true ]] && {
	    $ECHO docker run -e OSVC_CODE_TO_BUILD=${OSVC_CODE_TO_BUILD} -e OSVCDIST=${D} -e OSVCREPO=$LREPO -v ${OPBROOT}/tools:/tools --rm $LABEL build || return 1
    }
    [[ -f $HOME/.gitconfig ]] && GITCONFIG="-v $HOME/.gitconfig:/root/.gitconfig"
    [[ -f $HOME/.bashrc ]] && BASHRC="-v $HOME/.bashrc:/root/.bashrc"
    [[ $INTERACTIVE = true ]] && $ECHO docker run --hostname build-${D} -e OSVC_CODE_TO_BUILD=${OSVC_CODE_TO_BUILD} -e OSVCDIST=${D} -e OSVCREPO=$LREPO ${GITCONFIG} ${BASHRC} -v ${OPBROOT}/tools:/tools --rm -it $LABEL /bin/bash
    return 0
}

function usage()
{
  echo "Usage: $0 [ -b ] [ -c code ] [ -d ] [ -i ] [ -p ] [ -r ] -q distro" 1>&2
  echo
  echo "[ -b | --build       ] asks for docker image build"
  echo "[ -c | --code        ] set the target code to package (pull/123 or commit-id or branch)"
  echo "[ -d | --delete      ] asks for docker image delete"
  echo "[ -i | --interactive ] display docker commands to spawn interactive container"
  echo "[ -p | --package     ] asks for package build"
  echo "[ -q | --qa          ] set the targeted qa/distro environment"
  echo "[ -r | --run         ] actually execute the commands (default only echo commands to stdout)"
  echo
  echo "Supported distros: ${DISTROS[@]}"
  echo
  echo "Examples"
  echo "$0 -b -q debian12    # display interactive command to build a debian12 container image"
  echo "$0 -i -q debian12    # display interactive command to spawn a debian12 build env"
  echo "$0 -p -q debian12    # display command to build a debian12 package"
  echo "$0 -r -p -q debian12    # run command to build a debian12 package"
  echo "$0 -c pull/123 -r -p -q debian12    # run command to build a debian12 package corresponding to github pr pull/123"
  echo "$0 -c edcb0dbb792aff13bc5efc856623560e247ef10a -r -p -q debian12    # run command to build a debian12 package corresponding to github commit edcb..."
  echo 
}

function exit_abnormal()
{
  usage
  exit 1
}

OPTS=`getopt -o bc:dipq:r --long build,code:,delete,interactive,package,qa:,run -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2; exit_abnormal; fi

eval set -- "$OPTS"

while true; do
  case "$1" in
    -b | --build)
      BUILDIMG="true";
      shift
      ;;
    -c | --code)
      OSVC_CODE_TO_BUILD=$2;
      shift 2
      ;;
    -d | --delete)
      DELIMG="true";
      shift
      ;;
    -i | --interactive)
      INTERACTIVE="true";
      shift
      ;;
    -p | --package)
      PACKAGE="true";
      shift
      ;;
    -q | --qa)
      OSVC_DISTRO=$2;
      shift 2
      ;;
    -r | --run)
      ECHO="";
      shift
      ;;
    -- ) shift; break ;;
    *)
      exit_abnormal
      ;;
  esac
done

[[ -z "$OSVC_DISTRO" ]] && exit_abnormal
[[ -z "$BUILDIMG" && -z "$DELIMG" && -z "$INTERACTIVE" && -z "$PACKAGE" ]] && exit_abnormal

shift $((OPTIND-1))

#echo "---- $@ ----"

isdistro "${OSVC_DISTRO}" && {
	title ${OSVC_DISTRO}
	cmds ${OSVC_DISTRO} || exit 1
}

exit 0
