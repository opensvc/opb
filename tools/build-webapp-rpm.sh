#!/usr/bin/env bash

set -a

RPMBUILDTOP="$ROOTSCRIPTS/tmp-webapp/rpmbuild/${OSVCDIST}"
SPECFILE="$RPMBUILDTOP/SPECS/opensvc-webapp.spec"
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
    rm -rf /run/tmp
    mkdir -p /run/tmp
    cd /run/tmp && {
        mkdir opensvc-webapp-${PATTERN}
        cp /cache/github-releases/opensvc/om3-webapp/${OSVC_CODE_TO_BUILD}/index.html ./opensvc-webapp-${PATTERN}/
	tar czvf opensvc-webapp-${PATTERN}.tar.gz opensvc-webapp-${PATTERN}
	mv opensvc-webapp-${PATTERN}.tar.gz $SOURCES/
	find $RPMBUILDTOP
	cd -
    }
}

function gen_spec {
local LRELEASE="${PATTERN#v}"
local LSOURCE0="opensvc-webapp-${PATTERN}"

cat - <<-EOF >$SPECFILE
Summary: $SUMMARYWEBAPP
Name: opensvc-webapp
URL: https://www.opensvc.com
Vendor: OpenSVC
Version: $LRELEASE
Release: 1%{?dist}
Source0: ${LSOURCE0}.tar.gz
License: ASL 2.0
AutoReqProv: no
Conflicts: opensvc <= 2.2
BuildArch: noarch

%{?el7:Requires: opensvc-server}
%{?el8:Requires: opensvc-server}
%{?el9:Requires: opensvc-server}
%{?el10:Requires: opensvc-server}

%description
$(echo ${DESCRIPTIONWEBAPP}|fold -s)

%prep
echo "OSVC: ROOTSCRIPTS = $ROOTSCRIPTS"
echo "OSVC: RPMBUILDTOP = $RPMBUILDTOP"
echo "OSVC: BUILDROOT = %{buildroot}"

%setup -q

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/share/opensvc/html
install -m 0644 index.html %{buildroot}/usr/share/opensvc/html/index.html

%files
/usr/share/opensvc/html/index.html

%changelog
$CHANGELOG

EOF
}

## %define _rpmfilename $RPMFNAME

function build_rpm {
    rpmbuild -vvv --debug --define "_topdir $ROOTSCRIPTS/tmp-webapp/rpmbuild/${OSVCDIST}" --clean -ba $SPECFILE
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

    echo "PATTERN=$PATTERN" >> $ARTIFACT

    echo
    cat $ARTIFACT
    echo
    check_data $ARTIFACT REPO SRPM SRPMSHA256 PATTERN || return 1

    # noarch rpm files
    ARCH="noarch"
    for prefix in opensvc-webapp
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

        echo "PATTERN=$PATTERN" >> $ARTIFACT
    
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
