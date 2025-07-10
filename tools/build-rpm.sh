#!/usr/bin/env bash

set -a

RPMBUILDTOP="$ROOTSCRIPTS/tmp/rpmbuild/${OSVCDIST}"
SPECFILE="$RPMBUILDTOP/SPECS/opensvc.spec"
CHANGELOG=$(changelog)

PATTERN=$(gen_pattern)
echo 
echo "PATTERN <$PATTERN>"
echo 

function set_rpmmacros()
{
	cat - <<-EOF >/root/.rpmmacros
%_signature gpg
%_gpg_path /root/.gnupg
%_gpg_name OpenSVC
%_gpgbin /usr/bin/gpg
EOF
}

function prepare_rpmbuildtop {
    SOURCES="$RPMBUILDTOP/SOURCES"
    for DIR in BUILD RPMS SOURCES SPECS SRPMS
    do
        mkdir -p $RPMBUILDTOP/$DIR
    done
    ( cd ${OSVC} && \
      git config tar.umask 0022 && \
      git archive --prefix=opensvc-${PATTERN}/ --format=tar.gz HEAD > \
      $SOURCES/opensvc-${PATTERN}.tar.gz )
}

function gen_spec {
local LRELEASE="$PATTERN"
local LSOURCE0="opensvc-${PATTERN}"

cat - <<-EOF >$SPECFILE
Summary: $SUMMARYSRV
Name: opensvc
URL: https://www.opensvc.com
Vendor: OpenSVC
Version: $LRELEASE
Release: 1%{?dist}
Source0: ${LSOURCE0}.tar.gz
%{?el7:Requires: systemd}
%{?el8:Requires: systemd-rpm-macros}
%{?el9:Requires: systemd-rpm-macros}
License: ASL 2.0
AutoReqProv: no
Conflicts: opensvc <= 2.2
Obsoletes: opensvc
%define _source_filedigest_algorithm 1
%define _binary_filedigest_algorithm 1
%define _source_payload w9.gzdio
%define _binary_payload w9.gzdio
%define osvc_server_binary_name om
%define osvc_client_binary_name ox
%define osvc_compobj_binary_name compobj
%global completions_dir %( pkg-config --variable=completionsdir bash-completion )

# disable binary stripping
# %global debug_package %{nil}

%description
$(echo ${DESCRIPTIONSRV}|fold -s)

%package server
Summary: $SUMMARYSRV
Provides: /usr/bin/%{osvc_server_binary_name}
%{?el8:Recommends: sg3-utils, bash-completion, opensvc-client}
%{?el9:Recommends: sg3-utils, bash-completion, opensvc-client}
%description server
$DESCRIPTIONSRV

%package client
Summary: $SUMMARYCLI
Provides: /usr/bin/%{osvc_client_binary_name}
%description client
$DESCRIPTIONCLI

%prep
echo "OSVC: ROOTSCRIPTS = $ROOTSCRIPTS"
echo "OSVC: RPMBUILDTOP = $RPMBUILDTOP"
echo "OSVC: BUILDROOT = %{buildroot}"

%setup -q -n %{name}-${PATTERN}
echo ${TAG} > util/version/text/VERSION

%build
make om
make ox
make compobj
strip --strip-all bin/*

%check
./bin/%{osvc_server_binary_name} node version > binary.commit
grep -qw ${TAG} binary.commit && echo "PASS: om binary version OK" || (echo "FAIL: om binary version did not match current commit ($TAG)" && exit 1)

%install
#rm -rf "%{buildroot}"
install -m 0755 -d "%{buildroot}"
install -Dpm 0644 $ROOTSCRIPTS/files/systemd.opensvc-server.service %{buildroot}%{_unitdir}/opensvc-server.service

# /usr/bin/om
install -Dpm 0755 bin/%{osvc_server_binary_name} %{buildroot}%{_bindir}/%{osvc_server_binary_name}
install -Dpm 0755 bin/%{osvc_server_binary_name} $ROOTSCRIPTS/out/${OSVCDIST}/%{osvc_server_binary_name}.${OSVCDIST}

# /usr/bin/ox
install -Dpm 0755 bin/%{osvc_client_binary_name} %{buildroot}%{_bindir}/%{osvc_client_binary_name}
install -Dpm 0755 bin/%{osvc_client_binary_name} $ROOTSCRIPTS/out/${OSVCDIST}/%{osvc_client_binary_name}.${OSVCDIST}

# /etc/opensvc
mkdir -p %{buildroot}%{_sysconfdir}/opensvc

# /var/lib/opensvc
mkdir -p %{buildroot}%{_localstatedir}/lib/opensvc

# /var/log/opensvc
mkdir -p %{buildroot}%{_localstatedir}/log/opensvc

# /usr/lib/opensvc
mkdir -p %{buildroot}%{_libdir}/opensvc
install -Dpm 0755 bin/%{osvc_compobj_binary_name} %{buildroot}%{_libdir}/opensvc/%{osvc_compobj_binary_name}
install -Dpm 0755 bin/%{osvc_compobj_binary_name} $ROOTSCRIPTS/out/${OSVCDIST}/%{osvc_compobj_binary_name}.${OSVCDIST}

# /usr/share/opensvc/compliance
mkdir -p %{buildroot}%{_datadir}/opensvc/compliance
cd %{buildroot}%{_libdir}/opensvc; ./%{osvc_compobj_binary_name} -r -i ../../share/opensvc/compliance
find %{buildroot}%{_datadir}/opensvc/compliance

# /usr/share/bash-completion/completions/o[m|x]
mkdir -p %{buildroot}%{completions_dir}
%{buildroot}%{_bindir}/%{osvc_server_binary_name} completion bash > %{buildroot}%{completions_dir}/%{osvc_server_binary_name}
%{buildroot}%{_bindir}/%{osvc_client_binary_name} completion bash > %{buildroot}%{completions_dir}/%{osvc_client_binary_name}

# /usr/share/doc/opensvc
mkdir -p %{buildroot}%{_datadir}/doc/opensvc

# /usr/share/opensvc/html
mkdir -p %{buildroot}%{_datadir}/opensvc/html


%pre


%post server
%systemd_post opensvc-server.service

%preun server
%systemd_preun opensvc-server.service

%postun server
%systemd_postun_with_restart opensvc-server.service

%files server
%defattr(0644,root,root,0755)
%config(noreplace) %{_sysconfdir}/opensvc
%{_localstatedir}/lib/opensvc
%{_localstatedir}/log/opensvc
%{completions_dir}/%{osvc_server_binary_name}
%{_datadir}/doc/opensvc
%{_datadir}/opensvc
%{_libdir}/opensvc
%attr(0755, root, root) %{_bindir}/%{osvc_server_binary_name}
%attr(0755, root, root) %{_libdir}/opensvc/%{osvc_compobj_binary_name}
%{_unitdir}/opensvc-server.service

%files client
%defattr(0644,root,root,0755)
%attr(0755, root, root) %{_bindir}/%{osvc_client_binary_name}
%{completions_dir}/%{osvc_client_binary_name}

%changelog
$CHANGELOG

EOF
}

## %define _rpmfilename $RPMFNAME

function build_rpm {
    #rpmbuild --debug --define "osvc_chrootpkg $CHROOTPKG" --define "_topdir $ROOTSCRIPTS/tmp/rpmbuild/${OSVCDIST}" --clean -ba $SPECFILE
    rpmbuild -vvv --debug --define "_topdir $ROOTSCRIPTS/tmp/rpmbuild/${OSVCDIST}" --clean -ba $SPECFILE
    ret=$?
echo
    echo "rpmbuild ret code <$ret>"
echo
    #source only#rpmbuild --debug --undefine _rpmfilename --define "_topdir $ROOTSCRIPTS/tmp/rpmbuild/${OSVCDIST}" --clean -ba $SPECFILE
    #BUILDROOT=${BUILDROOT}
    #echo BUILDROOT=$BUILDROOT
    echo RPMBUILDTOP=$RPMBUILDTOP
    which rpmlint >/dev/null 2>&1 && {
        find $RPMBUILDTOP -name \*.rpm | xargs -I @ -n1 sh -c 'echo -e "\n=> rpmlinting @"; sha256sum @; rpmlint @ ; echo'
    }
    return $ret
}

function check_gpg_sign()
{
    pkgfile=$1
    refkey=$2

    pkgkey=$(rpm -qp --qf '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{(none)}|}|\n' ${pkgfile} | awk '{print $NF}')
    [[ ${refkey} != ${pkgkey} ]] && {
	    echo "package $pkgfile is not signed with expected gpg key ${refkey}"
	    exit 1
    }
}

function expose_data {
    DATAROOT="$ROOTSCRIPTS/out/$OSVCDIST"

    test -d $DATAROOT && rm -rf $DATAROOT
    mkdir -p $DATAROOT

    # source rpm file
    ARTIFACT="$DATAROOT/opensvc.$CURRENT_COMMIT.$OSVCDIST"
    echo "REPO=$OSVCREPO" | sed -e 's/-rpms/-srpms/' >> $ARTIFACT
    SRPMF=$(ls -1 $RPMBUILDTOP/SRPMS/*.rpm)
    SRPM=$(basename $SRPMF)
    cp -f $RPMBUILDTOP/SRPMS/$SRPM $DATAROOT
    echo "SRPM=$SRPM" >> $ARTIFACT
    echo "PKGARCH=source" >> $ARTIFACT
   
    SRPMSHA256=$(sha256sum $DATAROOT/$SRPM | awk '{print $1}')
    echo "SRPMSHA256=$SRPMSHA256" >> $ARTIFACT

    echo
    cat $ARTIFACT
    echo
    check_data $ARTIFACT REPO SRPM SRPMSHA256 || return 1

    # binary rpm files
    for prefix in opensvc-client opensvc-server
    do
        ARTIFACT="$DATAROOT/$prefix.$CURRENT_COMMIT.$OSVCDIST"

        echo "REPO=$OSVCREPO" >> $ARTIFACT
    
        RPMF=$(ls -1 $RPMBUILDTOP/RPMS/$ARCH/$prefix*.rpm)
	RPM=$(basename $RPMF)
        cp -f $RPMBUILDTOP/RPMS/$ARCH/$RPM $DATAROOT
        echo "RPM=$RPM" >> $ARTIFACT
        echo "PKGARCH=$ARCH" >> $ARTIFACT
    
        RPMSHA256=$(sha256sum $DATAROOT/$RPM | awk '{print $1}')
        echo "RPMSHA256=$RPMSHA256" >> $ARTIFACT
    
        echo
        ls -l $DATAROOT
        echo
        cat $ARTIFACT
        echo
        check_data $ARTIFACT REPO RPM RPMSHA256 || return 1
    done

    # sign pkg
    rpmsign --addsign $DATAROOT/*.rpm || return 1
    for pkg in $(ls -1 $DATAROOT/*.rpm)
    do
        check_gpg_sign $pkg $GPGKEYID
    done

    return 0
}

function cleanup {
    rm -rf $RPMBUILDTOP
}

echo "==> Cleanup"
cleanup || exit 1

echo "==> Setup gpg"
setup_gpg_repo

echo "==> Setup rpmmacros"
set_rpmmacros

echo "==> Preparing buildroot"
prepare_rpmbuildtop || exit 1

echo "==> Preparing rpm specfile"
gen_spec || exit 1

echo "==> Building rpm package"
build_rpm || exit 1

echo "==> Exposing generated datas"
expose_data || exit 1

echo "==> Cleanup"
cleanup || exit 1
