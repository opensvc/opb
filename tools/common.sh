# common code to rpm & deb build automation

# can be one of:
# - a pull request like "pull/123"
# - a commit-id like "d8d63dec0ecd0aeb8e0ba2807fd85a1446106fa2"
# - a branch name like "fix-scsi3-pgr"
# - empty variable
OSVC_CODE_TO_BUILD="${OSVC_CODE_TO_BUILD}"

# check if the current commit is associated with tag
# if yes, we should provide a user friendly filename
# if no, we are in an intermediate developper/debug release, with non friendly filename
# semver software version
VERSION=""                # semver 3.1.2

# string returned by om node version
# 3.1.2
# 3.1.2~alpha12-ga2b1c34354
VERSIONSTRING=""          # string returned by om node version 3.1.2 or 3.1.2~alpha12-ga2b1c34354

# true if official public release (git annotated tag)
# false if internal release (git lightweight tag)
ISRELEASE=""

# true if github pull request, else false
# if true, pr id is added in version string
ISPULLREQUEST="false"

# pull request number (123 in pull/123)
PULLREQUESTID=""

# source code git repository path
OSVC="/opt/opensvc"

# generic descriptions used in package manifest
SUMMARYSRV="Cluster and configuration management agent"
SUMMARYCLI="Cluster remote management client"
DESCRIPTIONSRV="A cluster agent to deploy, start, stop, monitor and relocate applications \
described as services."
DESCRIPTIONCLI="A client to remotely manage OpenSVC clusters"

# machine architecture
ARCH=$(arch)

function changelog() {
    ( cd $OSVC && \
        git log -n 100 --pretty=format:"* %cd %an <%ae>%n- %s" | \
    # strip tz
    sed -e "s/ [+\-][0-1][0-9][0-5][0-9] / /g" | \
    # strip time
    sed -e "s/ [0-2][0-9]:[0-5][0-9]:[0-5][0-9] / /g" | sed -e "s/%//"
    )
}

function check_data() {
    ARTIFACT=$1
    shift
    VARS="$@"
    for V in $VARS
    do
        [ -z "$V" ] && {
            echo "error: variable $V is empty"
            return 1
        }
    done
    return 0
}

function title() {
    local LEN=$((${#1}+2))
    printf "\n+"
    printf -- "-%.0s" $(seq 1 $LEN)
    printf "+\n| $1 |\n+"
    printf -- "-%.0s" $(seq 1 $LEN)
    printf "+\n\n"
}

function is_pull_request() {
    echo "$1" | grep -qE "^pull/[1-9][0-9]*$" > /dev/null && return 0 || return 1
}

function is_commit() {
    echo "$1" | grep -qE '^[a-z0-9]{40}$' > /dev/null && return 0 || return 1
}

function update_repo() {
    title "UPDATING GIT REPO"
    sudo git config --global --add safe.directory ${OSVC} >> /dev/null 2>&1
    cd ${OSVC} && { 
        sudo git pull --all --tags --progress || exit 1
    }
}

function gen_pattern() {
      # build a package version string (rpm and deb compliant)
      # 3.0.1
      # 3.0.1~1.gee27b62f
      # 3.0.1~alpha3.0.ga3e2f4e2
      # 3.0.1+feature.4.g12abc54e3

      # dpkg --compare-versions "3.0.1" "lt" "3.0.1+1.gee27b62f"           => TRUE
      # rpmdev-vercmp 0 3.0.1 1.el9 0 3.0.1+1.gee27b62f 1.el9              => 0:3.0.1-1.el9 < 0:3.0.1+1.gee27b62f-1.el9

      # dpkg --compare-versions "3.0.1~alpha9.0.g06368969" "lt" "3.0.1"    => TRUE
      # rpmdev-vercmp 0 3.0.1~alpha9.0.g06368969 1.el9 0 3.0.1 1.el9       => 0:3.0.1~alpha9.0.g06368969-1.el9 < 0:3.0.1-1.el9

      # dpkg --compare-versions "3.0.1" "lt" "3.0.1+feature.4.g12abc54e3"  => TRUE
      # rpmdev-vercmp 0 3.0.1 1.el9 0 3.0.1+feature.4.g12abc54e3 1.el9     => 0:3.0.1-1.el9 < 0:3.0.1+feature.4.g12abc54e3-1.el9

      local STR
      if [ "$ISRELEASE" = true ] ; then
	  # official public release
          STR="$VERSION"
      else
	  # example: first commit after a public release v3.0.1 => 3.0.1+1.gee27b62f
          STR="$VERSION+$GITDESC"

	  # if tag match alpha/beta/rc we add a ~ to mark package as a lower version than the official release
          if $(echo $GITDESC | grep -Eq "^alpha|^beta|^rc"); then
		  STR=${STR/\+/\~}
	  fi

          # if github pr, add pr id
          if [ "$ISPULLREQUEST" = true ] ; then
              STR="$STR+pr$PULLREQUESTID"
	  fi
      fi
      echo $STR
}

function get_current_commit() {
	CID=$(cd $OSVC && git log -1 --pretty=format:%H)
	echo $CID
}

function checkout_pull_request() {
    is_pull_request $1 || return 0
    ISPULLREQUEST="true"
    PULLREQUESTID=$(basename $1)
    title "Checkout pull request $PULLREQUESTID to $OSVC"
    cd ${OSVC} || return 1
    echo "git fetch origin +refs/pull/$PULLREQUESTID/merge ..."
    git fetch origin +refs/pull/$PULLREQUESTID/merge || return 1
    echo "git checkout FETCH_HEAD..."
    git checkout FETCH_HEAD || return 1
    echo
    title "Show pull request logs"
    echo "git log FETCH_HEAD...origin/main | head -n 100"
    git log FETCH_HEAD...origin/main | head -n 100
    return 0
}

function checkout_branch() {
    CURRENT_BRANCH=$(cd ${OSVC} && git branch --show-current)
    
    if [ -z ${OSVC_BRANCH+x} ];
    then {
        echo "variable branch is unset, using ${CURRENT_BRANCH}";
    }
    else {
        echo "variable branch is set to '$OSVC_BRANCH'";
        (cd ${OSVC} && git checkout ${BRANCH})
        CURRENT_BRANCH=$(cd ${OSVC} && git branch --show-current)
        if [ "${BRANCH}" != "${CURRENT_BRANCH}" ]; then
            echo "Error while trying to checkout branch ${BRANCH}. Exiting."
            exit 1
        fi
    }
    fi
}

function checkout_commit() {
    is_commit "$1" || return 0
    OSVC_COMMIT=$1
    echo "variable OSVC_COMMIT is set to '${OSVC_COMMIT}'";
    (cd ${OSVC} && git reset --hard ${OSVC_COMMIT})
    CURRENT_COMMIT=$(get_current_commit)
    if [ "${OSVC_COMMIT}" != "${CURRENT_COMMIT}" ]; then
            echo "Error while trying to git reset to commit id ${OSVC_COMMIT}. Exiting."
            exit 1
    fi
}

function checkout_code() {
    if is_pull_request $1 ; then
        checkout_pull_request $1 || return 1
    elif is_commit $1 ;then
        checkout_commit $1 || return 1
    else
        checkout_branch $1 || return 1
    fi
}

### main  ###

# refresh git repo content
update_repo

[[ -z ${OSVC_CODE_TO_BUILD} ]] && {
	echo "variable OSVC_CODE_TO_BUILD is empty, defaulting to latest upstream commit id in main branch"
	OSVC_CODE_TO_BUILD=$(get_current_commit)
}

# aligning repo content on target code to package
checkout_code ${OSVC_CODE_TO_BUILD} || exit 1

# updating commit id after code checkout
CURRENT_COMMIT=$(get_current_commit)

# git tagging documentation
# https://git-scm.com/book/en/v2/Git-Basics-Tagging
# annotated tag is used for public official releases
# lightweight tag is used for any other internal usage

# checking if public or internal release
TAG=$(cd $OSVC && git describe --exact-match HEAD 2>/dev/null)
RET=$?
# RET=0 if annotated tag
# RET!=0 if lightweight tag

if test ${RET} -eq 0
then
    # public release
    # git annotated tag  [git tag -a v3.1.0 -m "my version 3.1.0"]
    echo "ANNOTATED TAG => PUBLIC RELEASE"
    ISRELEASE=true
else
    # internal release
    # git lightweight tag [git tag v3.1.0-alpha12]
    echo "LIGHTWEIGHT TAG => INTERNAL RELEASE"
    ISRELEASE=false
    TAG=$(cd $OSVC && git describe --tags --match 'v*' --long)
fi

# TAG can be v3.4.5 or v3.4.5-alpha9-0-g06368969
VERSION=${TAG%%-*}             # v3.4.5
VERSION=${VERSION#v}           # 3.4.5
VERSIONSTRING=${TAG#v}         # 3.4.5 or 3.4.5-alpha9-0-g06368969
GITDESC=${TAG#*-}              # alpha9-0-g06368969
GITDESC=${GITDESC//-/.}        # alpha9.0.g06368969 [error: line 6: Illegal char '-' (0x2d) in: Release: 3.0.0~alpha8-167-g4fd31b50.el9]

echo "##################################################"
echo "#  OSVC_CODE_TO_BUILD : $OSVC_CODE_TO_BUILD"
echo "#  ISPULLREQUEST      : $ISPULLREQUEST"
echo "#  ISRELEASE          : $ISRELEASE"
echo "#  ARCH               : $ARCH"
echo "#  TAG                : $TAG"
echo "#  VERSION            : $VERSION"
echo "#  VERSIONSTRING      : $VERSIONSTRING"
echo "#  GITDESC            : $GITDESC"
echo "#  PATTERN            : $(gen_pattern)"
echo "#  COMMIT             : $CURRENT_COMMIT"
echo "##################################################"

id builder 2>/dev/null && chown -Rh builder:builder /home/builder
