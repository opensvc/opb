#!/usr/bin/env bash

set -ea

GIT="git"

function changelog {
    TGTDIST="unstable"
    [[ "$ISRELEASE" == "true" ]] && TGTDIST="stable"
    ( cd /opt/opensvc && \
      local PATTERN=$(gen_pattern)
      $GIT log --date=rfc2822 -n 1 --pretty=format:"opensvc (__V__) $TGTDIST; urgency=medium%n%n  * %s%n%n -- %an <%ae>  %ad%n" | \
      awk -v VERSIONRELEASE="$PATTERN" '{ sub(/__V__/,VERSIONRELEASE,$0); print $0 }'
    )
}

function prepare_debbuildtop {
    local PATTERN=$(gen_pattern)
    echo "PATTERN <$PATTERN>"
    [[ -d $DEBBUILDTOP ]] && sudo rm -rf $DEBBUILDTOP
    sudo mkdir -p $DEBBUILDTOP && sudo chown -Rh builder:builder $DEBBUILDTOP
    ( cd /opt/opensvc && \
      $GIT config tar.umask 0022 && \
      $GIT archive --prefix=opensvc-${PATTERN}/ --format=tar.gz HEAD > \
      $DEBBUILDTOP/opensvc_${PATTERN}.orig.tar.gz )
    ( cd $DEBBUILDTOP && tar xf opensvc_${PATTERN}.orig.tar.gz )
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
Source: opensvc
Maintainer: OpenSVC <support@opensvc.com>
Section: admin
Testsuite: autopkgtest-pkg-go
Priority: optional
Build-Depends: bash-completion,
               debhelper-compat (= 12),
               dh-exec,
               golang-any

Package: opensvc-server
Section: admin
Priority: optional
Architecture: any
Depends: \${misc:Depends},
         \${shlibs:Depends}
Built-Using: \${misc:Built-Using}
Recommends: sg3-utils
Provides: opensvc-server
Description: $SUMMARYSRV
EOF

echo "$DESCRIPTIONSRV" | sed -e "s/^/ /" >>$DEBIANFILESDIR/control
echo >> $DEBIANFILESDIR/control

    cat - <<-EOF >>$DEBIANFILESDIR/control
Package: opensvc-client
Section: admin
Priority: optional
Architecture: any
Depends: \${misc:Depends},
         \${shlibs:Depends}
Built-Using: \${misc:Built-Using}
Provides: opensvc-client
Description: $SUMMARYCLI
EOF

echo "$DESCRIPTIONCLI" | sed -e "s/^/ /" >>$DEBIANFILESDIR/control

}

function gen_copyright {
    cp $ROOTSCRIPTS/files/copyright $DEBIANFILESDIR/opensvc-server.copyright
    cp $ROOTSCRIPTS/files/copyright $DEBIANFILESDIR/opensvc-client.copyright
}

function gen_bash-completion {
    echo "debian/om-completion om" >> $DEBIANFILESDIR/opensvc-server.bash-completion
    echo "debian/ox-completion ox" >> $DEBIANFILESDIR/opensvc-client.bash-completion
}

function gen_rules {
    cp $ROOTSCRIPTS/files/debian.rules $DEBIANFILESDIR/rules
}

function gen_units {
    cp $ROOTSCRIPTS/files/systemd.opensvc-agent.service $DEBIANFILESDIR/opensvc-server.opensvc-agent.service
    cp $ROOTSCRIPTS/files/systemd.opensvc-agent.preset $DEBIANFILESDIR/80-opensvc-agent.preset
    cp $ROOTSCRIPTS/files/systemd.opensvc-services.service $DEBIANFILESDIR/opensvc-server.opensvc-services.service
}

function gen_install {
    cat - <<-EOF >$DEBIANFILESDIR/opensvc-server.install
#!/usr/bin/dh-exec
bin/om => /usr/bin/om
bin/compobj => /usr/lib/opensvc/compobj
debian/80-opensvc-agent.preset /usr/lib/systemd/system-preset/
EOF

    cat - <<-EOF >$DEBIANFILESDIR/opensvc-client.install
#!/usr/bin/dh-exec
bin/ox => /usr/bin/ox
EOF

chmod +x $DEBIANFILESDIR/opensvc-server.install $DEBIANFILESDIR/opensvc-client.install
}

function gen_dirs {
    cat - <<-EOF >$DEBIANFILESDIR/opensvc-server.dirs
etc/opensvc
var/lib/opensvc
var/tmp/opensvc
usr/share/opensvc/html
usr/lib/opensvc
EOF

}

function build_deb {
    (cd $DEBIANFILESDIR/.. && \
        dpkg-buildpackage --build=binary \
                          --hook-build=${ROOTSCRIPTS}/files/hook.build.sh \
                          --hook-done=${ROOTSCRIPTS}/files/hook.done.sh \
                      )
}

function expose_data {
    DATAROOT="$ROOTSCRIPTS/out/$OSVCDIST"

    test -d $DATAROOT && rm -rf $DATAROOT
    mkdir -p $DATAROOT

    for prefix in opensvc-client opensvc-server
    do
        ARTIFACT="$DATAROOT/$prefix.$CURRENT_COMMIT.$OSVCDIST"
        echo "REPO=$OSVCREPO" >> $ARTIFACT
        DEBF=$(ls -1 $DEBBUILDTOP/$prefix*.deb)
        DEB=$(basename $DEBF)
        cp $DEBBUILDTOP/$DEB $DATAROOT
        echo "DEB=$DEB" >> $ARTIFACT

        DEBSHA256=$(sha256sum $DATAROOT/$DEB | awk '{print $1}')
        echo "DEBSHA256=$DEBSHA256" >> $ARTIFACT

        echo
	title $prefix
        cat $ARTIFACT
        check_data $ARTIFACT REPO DEB DEBSHA256 || return 1
    done

    echo
    title "ls -l $DATAROOT"
    ls -l $DATAROOT
    return 0
}

function cleanup {
    echo "Cleanup"
    sudo rm -rf $DEBBUILDTOP
}



######################################
######################################
[[ -z "$OSVCDIST" ]] && exit 1
DEBBUILDTOP="$ROOTSCRIPTS/tmp/debbuild/${OSVCDIST}"
CHANGELOG=$(changelog)
PATTERN=$(gen_pattern)
DEBIANFILESDIR="$DEBBUILDTOP/opensvc-${PATTERN}/debian"

title "Preparing buildroot"
prepare_debbuildtop || exit 1

title "Preparing deb changelog"
gen_changelog || exit 1

title "Preparing deb control"
gen_control || exit 1

title "Preparing deb copyright"
gen_copyright || exit 1

title "Preparing bash completion"
gen_bash-completion || exit 1

title "Preparing deb rules"
gen_rules || exit 1

title "Preparing systemd unit files"
gen_units || exit 1

title "Preparing install file"
gen_install || exit 1

title "Preparing dirs file"
gen_dirs || exit 1

title "Building deb package"
build_deb || exit 1

title "Exposing generated datas"
expose_data || exit 1

#echo "==> Cleanup"
#cleanup || exit 1
