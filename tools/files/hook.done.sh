#!/bin/bash

[[ -z "$OSVCDIST" ]] && exit 1

echo
cd ${DEBBUILDTOP}

for pkg in $(ls -1rt *.deb)
do
    echo "--- dpkg-deb -I $pkg ---"
    dpkg-deb -I ${DEBBUILDTOP}/${pkg} || {
	echo "problem with deb package ${DEBBUILDTOP}/${pkg}"
	exit 1
    }
    echo -e "\n--- linting $pkg ---"
    # -c check
    # -i include detailed description
    # -I display informational messages
    lintian -c $pkg
    echo
done
