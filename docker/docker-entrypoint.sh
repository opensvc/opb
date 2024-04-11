#!/bin/sh
set -e

if [ "$1" = 'build' ]; then
    test -x /tools/run.sh && {
        echo "=> Building package"
        cd /tools && ./run.sh && exit 0
    }
    exit 1
fi

exec "$@"
