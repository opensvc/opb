#!/bin/sh
set -e

if [ "$1" = 'build' ]; then
    test -x /tools/run.sh && {
        echo "=> Building om3/ox package"
        cd /tools && ./run.sh && exit 0
    }
    exit 1
elif [ "$1" = "om3-webapp-build" ]; then
    test -x /tools/run.sh && {
        echo "=> Building om3-webapp package"
        cd /tools && ./run-webapp.sh && exit 0
    }
    exit 1

fi

exec "$@"
