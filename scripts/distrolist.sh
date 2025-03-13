#!/bin/bash

opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."

. ${opbroot}/environment.sh

data='{}'

for i in "${DISTROS[@]}"
do
    data=$(jq -n --arg data "$data" \
                 --arg key "$i"     \
                 --arg value "$i" \
                 '$data | fromjson + { ($key) : ($value | tostring) }')
done

socat -v -v TCP-LISTEN:8090,crlf,reuseaddr,fork SYSTEM:"echo HTTP/1.0 200; echo Content-Type\: application/json; echo; echo \'$data\'"
