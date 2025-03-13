#!/bin/bash

opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."

daemon="${opbscripts}/distrolist.sh"

. ${opbroot}/environment.sh

function status {
        pgrep -f $daemon >/dev/null 2>&1
}

case $1 in
start)
        status && {
                echo "already started"
                exit 0
        }
        nohup $daemon >> /dev/null 2>&1 &
        ;;
stop)
        pkill -f $daemon
	lsof -ti TCP:8090|xargs kill -9
        ;;
info)
        echo "Name: $0"
        ;;
status)
        status
        exit $?
        ;;
*)
        echo "unsupported action: $1" >&2
        exit 1
        ;;
esac
