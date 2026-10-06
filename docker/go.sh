#!/usr/bin/env bash

set -au

OPBDOCKER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OPBROOT="${OPBDOCKER}/.."

cd ${OPBDOCKER} || exit 1

. ${OPBROOT}/environment.sh

echo '------------------------------------'
echo "command: $0 $@"
echo '------------------------------------'

OSVC_GITREPO_URL="${OSVC_GITREPO_URL:-https://github.com/opensvc/om3.git}"
WEBAPP_GITREPO_URL="${WEBAPP_GITREPO_URL:-https://github.com/opensvc/om3-webapp.git}"
OSVC_GOLANG_URL="${OSVC_GOLANG_URL:-https://go.dev/dl/go1.26.4.linux-amd64.tar.gz}"
OSVC_CYCLONEDX_VERSION="${OSVC_CYCLONEDX_VERSION:-v0.30.0}"
REDHAT_ORG_ID="${REDHAT_ORG_ID:-1234567}"
REDHAT_ACT_KEY="${REDHAT_ACT_KEY:-my_secret_activation_key}"

BUILDIMG=""
DELIMG=""
INTERACTIVE=""
PACKAGE=""
ECHO="echo"
OSVCWEBAPP="false"
DCKBUILD="build"
OSVC_CODE_TO_BUILD=""
OSVC_DISTRO=""
FORCE=""
PKGREV="1"

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

# the webapp packages are distro independent: one deb and one noarch rpm,
# see rundeck-pkg-webapp.sh
function webapp_family()
{
    case $1 in
    rhel*|sles*) echo rpm-noarch ;;
    *)           echo deb-noarch ;;
    esac
}

function cmds()
{
    local D=$1
    local LABEL="$D:pkgbuild"
    local LABELBUILD="$D:pkgbuild-new"
    local COMMON_OPTS="--pull --network host --no-cache "
    local BUILDARG_OPTS="--build-arg OSVC_GITREPO_URL=$OSVC_GITREPO_URL --build-arg WEBAPP_GITREPO_URL=$WEBAPP_GITREPO_URL --build-arg OSVC_GOLANG_URL=$OSVC_GOLANG_URL --build-arg OSVC_CYCLONEDX_VERSION=$OSVC_CYCLONEDX_VERSION"
    local REDHAT_OPTS="--secret id=rh_org_id,src=$OPBDOCKER/rh_org_id.txt --secret id=rh_act_key,src=$OPBDOCKER/rh_act_key.txt"
    local DOCKER_OPTS="$COMMON_OPTS $BUILDARG_OPTS"
    local LREPO=${REPOS[$D]}
    local GITCONFIG=""
    echo $D | grep -q rhel && DOCKER_OPTS="$DOCKER_OPTS $REDHAT_OPTS"
    [[ $BUILDIMG = true ]] && {
	    $ECHO docker buildx build $DOCKER_OPTS -f Dockerfile.$D -t $LABELBUILD . || return 1
    }
    [[ $DELIMG = true ]] && {
	    $ECHO docker rmi -f $LABEL || return 1
    }
    [[ $PACKAGE = true && $OSVCWEBAPP = true ]] && {
	    # same build as the rundeck webapp job: asset download, one package
	    # per family in tools/webapp-out/<family>, internal version
	    [[ $FORCE = true ]] && {
		    $ECHO rm -f ${OPBROOT}/tools/webapp-out/.$(webapp_family $D).buildid || return 1
	    }
	    $ECHO env NAME=$D CODE=${OSVC_CODE_TO_BUILD} PKGREV=${PKGREV} RELEASE_NAME= PRERELEASE= ${OPBDOCKER}/rundeck-pkg-webapp.sh || return 1
    }
    [[ $PACKAGE = true && $OSVCWEBAPP != true ]] && {
	    $ECHO docker run -e OSVC_CODE_TO_BUILD=${OSVC_CODE_TO_BUILD} -e OSVCDIST=${D} -e OSVCREPO=$LREPO -e OSVCWEBAPP=${OSVCWEBAPP} -v ${OPBROOT}/tools:/tools -v ~builder/.cache:/cache --rm $LABEL $DCKBUILD || return 1
    }
    [[ -f $HOME/.gitconfig ]] && GITCONFIG="-v $HOME/.gitconfig:/root/.gitconfig"
    [[ -f $HOME/.bashrc ]] && BASHRC="-v $HOME/.bashrc:/root/.bashrc"
    local IDIST=$D
    # webapp: run-webapp.sh in the container writes where the rundeck job does
    [[ $OSVCWEBAPP = true ]] && IDIST=$(webapp_family $D)
    [[ $INTERACTIVE = true ]] && $ECHO docker run --hostname build-${D} -e OSVC_CODE_TO_BUILD=${OSVC_CODE_TO_BUILD} -e OSVCDIST=${IDIST} -e OSVCREPO=$LREPO -e OSVCWEBAPP=${OSVCWEBAPP} -e OSVC_PKGREV=${PKGREV} ${GITCONFIG} ${BASHRC} -v ${OPBROOT}/tools:/tools -v ${HOME}/.cache:/cache --rm -it $LABEL /bin/bash
    return 0
}

function usage()
{
  echo "Usage: $0 [ -b ] [ -c code ] [ -d ] [ -f ] [ -i ] [ -p ] [ -r ] [ -v rev ] [ -w ] -q distro" 1>&2
  echo
  echo "[ -b | --build       ] asks for docker image build"
  echo "[ -c | --code        ] set the target code to package (pull/123 or commit-id or branch)"
  echo "                       with -w: the om3-webapp release tag, mandatory with -p"
  echo "[ -d | --delete      ] asks for docker image delete"
  echo "[ -f | --force       ] with -w -p: rebuild even if the webapp packages are already built"
  echo "[ -i | --interactive ] display docker commands to spawn interactive container"
  echo "[ -p | --package     ] asks for package build"
  echo "[ -q | --qa          ] set the targeted qa/distro environment"
  echo "[ -r | --run         ] actually execute the commands (default only echo commands to stdout)"
  echo "[ -v | --pkgrev      ] with -w: package revision (deb revision, rpm release), default 1"
  echo "[ -w | --webapp      ] enable webapp packaging environment"
  echo
  echo "Supported distros: ${DISTROS[@]}"
  echo
  echo "Webapp packages (-w -p)"
  echo "  The webapp packages only ship the index.html asset of an om3-webapp github"
  echo "  release, they are distro independent: one deb, built in the debian12 image,"
  echo "  for every debian and ubuntu distro, and one noarch rpm, built in the rhel9"
  echo "  image, for every rhel and sles distro. The -q distro only selects the family."
  echo "  The build runs rundeck-pkg-webapp.sh, like the rundeck webapp job:"
  echo "  - index.html is downloaded from the -c release (waits up to 30 minutes for"
  echo "    the asset), into ~/.cache/github-releases"
  echo "  - the packages are written to tools/webapp-out/deb-noarch or rpm-noarch,"
  echo "    replacing the previous ones, where publish.sh (OSVCWEBAPP=true) reads them"
  echo "  - the version is the internal one, as for a dev build, ex 0.0.0~rc5.0.gd91e56c-1"
  echo "    (no RELEASE_NAME): for a final release tag like v1.0.0, it is not the"
  echo "    1.0.0-1 of the rundeck release job, but ex 1.0.0+0.g<commit>-1"
  echo "  - nothing is published"
  echo "  Already built packages:"
  echo "  - a build is skipped when the same code and revision were built last, in this"
  echo "    family (marker tools/webapp-out/.deb-noarch.buildid or .rpm-noarch.buildid,"
  echo "    shared with the rundeck job)"
  echo "  - -f removes the marker to rebuild anyway, ex after a change of the build"
  echo "    scripts or images. The rebuilt packages have the same version: a repository"
  echo "    that already has this version skips them at publication"
  echo "  - to republish a version after a packaging fix, use -v 2 (or more): the"
  echo "    revision changes the version, the build is not skipped"
  echo "  With -i, the container is the -q distro image, and OSVCDIST is the family:"
  echo "  run-webapp.sh run there writes to tools/webapp-out/<family> too"
  echo
  echo "Examples"
  echo "$0 -b -q debian12    # display interactive command to build a debian12 container image"
  echo "$0 -i -q debian12    # display interactive command to spawn a debian12 build env"
  echo "$0 -p -q debian12    # display command to build a debian12 package"
  echo "$0 -r -p -q debian12    # run command to build a debian12 package"
  echo "$0 -c pull/123 -r -p -q debian12    # run command to build a debian12 package corresponding to github pr pull/123"
  echo "$0 -c edcb0dbb792aff13bc5efc856623560e247ef10a -r -p -q debian12    # run command to build a debian12 package corresponding to github commit edcb..."
  echo "$0 -w -c v0.0.0-rc5 -r -p -q debian12    # run command to build the webapp deb of release v0.0.0-rc5"
  echo "$0 -w -c v0.0.0-rc5 -r -p -q rhel9    # run command to build the webapp noarch rpm of release v0.0.0-rc5"
  echo "$0 -w -c v0.0.0-rc5 -f -r -p -q debian12    # same, rebuilt even if already built"
  echo "$0 -w -c v0.0.0-rc5 -v 2 -r -p -q debian12    # same, revision 2: 0.0.0~rc5.0.gd91e56c-2"
  echo 
}

function exit_abnormal()
{
  usage
  exit 1
}

OPTS=`getopt -o bc:dfipq:rv:w --long build,code:,delete,force,interactive,package,pkgrev:,qa:,run,webapp -- "$@"`

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
    -f | --force)
      FORCE="true";
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
    -v | --pkgrev)
      PKGREV=$2;
      shift 2
      ;;
    -w | --webapp)
      OSVCWEBAPP="true";
      DCKBUILD="om3-webapp-build";
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
[[ $OSVCWEBAPP = true && $PACKAGE = true && -z "$OSVC_CODE_TO_BUILD" ]] && {
  echo -e "\nerror: -w -p needs the om3-webapp release tag (-c)\n"
  exit_abnormal
}
[[ $PKGREV =~ ^[1-9][0-9]*$ ]] || {
  echo -e "\nerror: -v needs a positive integer, got '${PKGREV}'\n"
  exit_abnormal
}

shift $((OPTIND-1))

#echo "---- $@ ----"

isdistro "${OSVC_DISTRO}" && {
	title ${OSVC_DISTRO}
	cmds ${OSVC_DISTRO} || exit 1
}

exit 0
