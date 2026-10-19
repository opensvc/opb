#!/bin/bash
#
# build-slot.sh: run a command once one of the package build slots is free.
#
# Limits the number of concurrent package builds on the builder node, so a
# burst of Rundeck executions (one per distro, relaunched on every PR push)
# does not saturate the host storage.
#
# usage: build-slot.sh <command> [args...]
#
# env:
#   BUILD_SLOTS      number of concurrent builds allowed (default 2)
#   BUILD_SLOT_DIR   lock files directory (default /var/tmp/opb-build-slots)
#   BUILD_SLOT_WAIT  max seconds to wait for a slot (default 10800)
#
# The slot is a flock on a file descriptor: it is released when the command
# exits, including when the Rundeck execution is aborted.

SLOTS=${BUILD_SLOTS:-2}
DIR=${BUILD_SLOT_DIR:-/var/tmp/opb-build-slots}
WAIT=${BUILD_SLOT_WAIT:-10800}

if [ $# -eq 0 ]; then
	echo "usage: $0 <command> [args...]" >&2
	exit 2
fi

mkdir -p "$DIR" || exit 1

start=$(date +%s)
last_msg=0
while :; do
	for i in $(seq 1 "$SLOTS"); do
		exec {fd}>>"$DIR/slot.$i"
		if flock -n "$fd"; then
			echo "build-slot: slot $i/$SLOTS acquired after $(( $(date +%s) - start ))s"
			"$@"
			exit $?
		fi
		exec {fd}>&-
	done
	now=$(date +%s)
	if [ $(( now - start )) -ge "$WAIT" ]; then
		echo "build-slot: no free slot after ${WAIT}s, giving up" >&2
		exit 1
	fi
	if [ $(( now - last_msg )) -ge 60 ]; then
		echo "build-slot: all $SLOTS slots busy, waiting ($(( now - start ))s)"
		last_msg=$now
	fi
	sleep 5
done
