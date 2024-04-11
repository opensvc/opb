#!/bin/bash

cd ${ROOTSCRIPTS}/tmp/debbuild/${OSVCDIST}

echo ${VERSIONSTRING} > opensvc-${PATTERN}/util/version/text/VERSION

echo "--- OPENSVC VERSION ---"
cat opensvc*/util/version/text/VERSION
