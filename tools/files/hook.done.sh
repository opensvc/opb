#!/bin/bash

[[ -z "$OSVCDIST" ]] && exit 1

echo
cd ${ROOTSCRIPTS}/tmp/debbuild/${OSVCDIST}

for pkg in $(ls -1rt *.deb)
do
    echo "--- dpkg-deb -I $pkg ---"
    dpkg-deb -I ${ROOTSCRIPTS}/tmp/debbuild/${OSVCDIST}/${pkg} || {
	echo "problem with deb package ${ROOTSCRIPTS}/tmp/debbuild/${OSVCDIST}/${pkg}"
	exit 1
    }
    echo
done
