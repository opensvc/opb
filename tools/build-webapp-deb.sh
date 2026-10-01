#!/usr/bin/env bash

set -ea

GIT="git"

function changelog {
    TGTDIST="unstable"
    [[ "$ISRELEASE" == "true" ]] && TGTDIST="stable"
    SRCROOT="/opt/opensvc"
    [[ "$OSVCWEBAPP" == "true" ]] && SRCROOT="/opt/om3-webapp"
    ( cd $SRCROOT && \
      local PATTERN=$(gen_pattern)
      $GIT log --date=rfc2822 -n 1 --pretty=format:"opensvc-webapp (__V__) $TGTDIST; urgency=medium%n%n  * %s%n%n -- %an <%ae>  %ad%n" | \
      awk -v VERSIONRELEASE="$PATTERN" '{ sub(/__V__/,VERSIONRELEASE,$0); print $0 }'
    )
}

function prepare_debbuildtop {
    local INDEX="/cache/github-releases/opensvc/om3-webapp/${OSVC_CODE_TO_BUILD}/index.html"
    [[ -f $INDEX ]] || {
        echo "missing $INDEX, run tools/fetch_release.sh opensvc om3-webapp ${OSVC_CODE_TO_BUILD} index.html"
        return 1
    }
    local PATTERN=$(gen_pattern)
    echo "PATTERN <$PATTERN>"
    [[ -d $DEBBUILDTOP ]] && sudo rm -rf $DEBBUILDTOP
    sudo mkdir -p $DEBBUILDTOP && sudo chown -Rh builder:builder $DEBBUILDTOP

    rm -rf /run/tmp
    mkdir -p /run/tmp
    cd /run/tmp && {
        mkdir opensvc-webapp-${PATTERN}
        cp $INDEX ./opensvc-webapp-${PATTERN}/ || return 1
	tar czvf opensvc-webapp-${PATTERN}.tar.gz opensvc-webapp-${PATTERN}
	mv opensvc-webapp-${PATTERN}.tar.gz $DEBBUILDTOP/opensvc-webapp_${PATTERN}.orig.tar.gz
	cd -
    }
    ( cd $DEBBUILDTOP && tar xf opensvc-webapp_${PATTERN}.orig.tar.gz )
}

function gen_changelog {
    [[ ! -d $DEBIANFILESDIR ]] && mkdir -p $DEBIANFILESDIR
    changelog > $DEBIANFILESDIR/changelog
}

function gen_compat {
    echo "12" > $DEBIANFILESDIR/compat
}

function gen_control {
    cat - <<-EOF >$DEBIANFILESDIR/control
Source: opensvc-webapp
Maintainer: OpenSVC <support@opensvc.com>
Section: web
Priority: optional
Build-Depends: debhelper-compat (= 12)
Standards-Version: 4.6.2

Package: opensvc-webapp
Section: web
Priority: optional
Architecture: all
Depends: opensvc-server
Provides: opensvc-webapp
Breaks: opensvc (<= 2.2)
Conflicts: opensvc (<= 2.2)
Description: $SUMMARYWEBAPP
EOF

echo "$DESCRIPTIONWEBAPP" | sed -e "s/^/ /" >>$DEBIANFILESDIR/control
}

function gen_copyright {
    cp $ROOTSCRIPTS/files/copyright $DEBIANFILESDIR/opensvc-webapp.copyright
}

function gen_rules {
    cp $ROOTSCRIPTS/files/debian-webapp.rules $DEBIANFILESDIR/rules
}

function setup_debsig {
    # keyring
    mkdir -p /usr/share/debsig/keyrings/${GPGKEYID^^}
    gpg --no-default-keyring \
        --keyring /usr/share/debsig/keyrings/${GPGKEYID^^}/debsig.gpg \
	 --import /tools/files/pkgsign_pub.gpg
    # policy
    mkdir -p /etc/debsig/policies/${GPGKEYID^^}
    cat /tools/files/keyid.pol | sed -e "s/GPGKEYID/${GPGKEYID^^}/" > /etc/debsig/policies/${GPGKEYID^^}/keyid.pol
}

function gen_install {
    cat - <<-EOF >$DEBIANFILESDIR/opensvc-webapp.install
#!/usr/bin/dh-exec
index.html => /usr/share/opensvc/html/index.html
EOF

chmod +x $DEBIANFILESDIR/opensvc-webapp.install
}

function gen_source_format {
    mkdir -p $DEBIANFILESDIR/source
    cat - <<-EOF >$DEBIANFILESDIR/source/format
3.0 (native)
EOF
}

function build_deb {
    (cd $DEBIANFILESDIR/.. && \
        dpkg-buildpackage --build=full \
                          --sign-key=${GPGKEYID} \
                          --hook-done=${ROOTSCRIPTS}/files/hook.done.sh \
                      )
}

function expose_data {
    DATAROOT="$ROOTSCRIPTS/webapp-out/$OSVCDIST"

    test -d $DATAROOT && rm -rf $DATAROOT
    mkdir -p $DATAROOT

    for prefix in opensvc-webapp
    do
        ARTIFACT="$DATAROOT/$prefix.$CURRENT_COMMIT.$OSVCDIST"
        echo "REPO=$OSVCREPO" >> $ARTIFACT
        DEBF=$(ls -1 $DEBBUILDTOP/$prefix*.deb)
        DEB=$(basename $DEBF)
        echo "DEB=$DEB" >> $ARTIFACT
        echo "PKGARCH=all" >> $ARTIFACT

        DEBSHA256=$(sha256sum $DEBBUILDTOP/$DEB | awk '{print $1}')
        echo "DEBSHA256=$DEBSHA256" >> $ARTIFACT

        echo "PATTERN=$PATTERN" >> $ARTIFACT

        echo
	title $prefix
        cat $ARTIFACT
        check_data $ARTIFACT REPO DEB DEBSHA256 PATTERN || return 1
    done
    # copy all files
    ( cd $DEBBUILDTOP && cp $(ls --file-type | grep -v '.*/$') $DATAROOT )

    echo
    title "ls -l $DATAROOT"
    ls -l $DATAROOT
    return 0
}

function cleanup {
    sudo rm -rf $DEBBUILDTOP
}

######################################
######################################
[[ -z "$OSVCDIST" ]] && exit 1
DEBBUILDTOP="$ROOTSCRIPTS/webapp-tmp/debbuild/${OSVCDIST}"
CHANGELOG=$(changelog)
PATTERN=$(gen_pattern)
DEBIANFILESDIR="$DEBBUILDTOP/opensvc-webapp-${PATTERN}/debian"

title "Cleanup"
cleanup || exit 1

echo "==> Setup gpg"
setup_gpg_repo

echo "==> Setup debsig"
setup_debsig

title "Preparing buildroot"
prepare_debbuildtop || exit 1

title "Preparing deb changelog"
gen_changelog || exit 1

title "Preparing deb control"
gen_control || exit 1

title "Preparing deb copyright"
gen_copyright || exit 1

title "Preparing deb rules"
gen_rules || exit 1

title "Preparing source files"
gen_source_format || exit 1

title "Preparing install file"
gen_install || exit 1

title "Building deb package"
build_deb || exit 1

title "Exposing generated datas"
expose_data || exit 1

echo "==> Cleanup"
#cleanup || exit 1
