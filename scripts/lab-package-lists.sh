#!/bin/bash
#
# Build the json lists of the opensvc packages available for each lab
# distribution, newest first, 10 entries at most. They are served by the
# "lablists" service (python http.server on :8091) and consumed by the Rundeck
# jobs "LAB V3 DEPLOY CLUSTER" and "LAB V2 DEPLOY CLUSTER" as remote option
# values:
#
#   http://builder.opensvc.com:8091/v3/lab/svc/<distro>.json
#       v3 release (prod-opensvc-v3-*) and pre-release (uat-opensvc-v3-*) packages, from packages.opensvc.com
#   http://builder.opensvc.com:8091/v2/lab/svc/<distro>.json
#       v2 packages, from repo.opensvc.com
#
# Each file is a JSON array of {"name": <label>, "value": <value>}:
#   v3 value: <repository>|<package version>   ex: prod-opensvc-v3-noble|3.0.0~rc50.0.g947a93d00+ubuntu24.04
#   v2 value: <path on repo.opensvc.com>        ex: deb/2.1/opensvc_2.1-996_all.deb
#
# The distributions and the repository names come from environment.sh
# (DISTROS and REPOS, the dev- repositories renamed prod-/uat-), like distrolist.sh.

set -u
opbscripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
opbroot="${opbscripts}/.."
. ${opbroot}/environment.sh

WWW=${WWW:-/home/builder/lablists/www}
MAX=${MAX:-10}
V3_URL=https://packages.opensvc.com
V2_URL=https://repo.opensvc.com
CURL="curl -sS -f -m 30"

json_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }

# apt flavor of a distro, or "rpm"
flavor_of() {
    case $1 in
    u*)       echo ubuntu ;;
    debian*)  echo debian ;;
    *)        echo rpm ;;
    esac
}

# print "<version>\t<repo>" lines for one v3 repository (prod or uat)
v3_versions() {
    local flavor=$1 repo=$2
    if [ "$flavor" = rpm ]; then
        $CURL "$V3_URL/rpm/$repo/x86_64/" 2>/dev/null \
        | grep -oE 'href="opensvc-server-[^"]+\.rpm"' \
        | sed -e 's/href="opensvc-server-//' -e 's/\.x86_64\.rpm"//' -e 's/%2B/+/g; s/%7E/~/g' \
        | awk -v r="$repo" '{print $0 "\t" r}'
    else
        $CURL "$V3_URL/apt/$flavor/dists/$repo/main/binary-amd64/Packages" 2>/dev/null \
        | awk -v r="$repo" '/^Package: opensvc-server$/{p=1} p && /^Version:/{print $2 "\t" r; p=0}'
    fi
}

write_v3() {
    local name=$1 flavor=$2 devrepo=$3 out=$WWW/v3/lab/svc/$name.json tmp
    tmp=$(mktemp)
    {
        v3_versions "$flavor" "${devrepo/#dev-/prod-}"
        v3_versions "$flavor" "${devrepo/#dev-/uat-}"
    } | sort -t$'\t' -k1,1 -rV | awk -F'\t' '!seen[$1]++' | head -n "$MAX" > "$tmp"
    {
        echo "["
        local first=1 ver repo kind
        while IFS=$'\t' read -r ver repo; do
            [ -z "$ver" ] && continue
            case $repo in uat-*) kind=prerelease ;; *) kind=release ;; esac
            [ $first = 1 ] || echo ","
            first=0
            printf '  {"name": "%s %s", "value": "%s|%s"}' "$kind" "$(echo "$ver" | json_escape)" "$repo" "$(echo "$ver" | json_escape)"
        done < "$tmp"
        echo
        echo "]"
    } > "$tmp.json"
    rm -f "$tmp"
    install_file "$tmp.json" "$out" "v3 $name"
}

# print "<version>\t<path>" lines for the v2 packages of one family
v2_versions() {
    local flavor=$1
    if [ "$flavor" = rpm ]; then
        $CURL "$V2_URL/rpms/2.1/" 2>/dev/null \
        | grep -oE 'href="opensvc-2\.1-[0-9]+\.noarch\.rpm"' \
        | sed 's/href="//; s/"//' \
        | awk '{v=$0; sub(/^opensvc-/,"",v); sub(/\.noarch\.rpm$/,"",v); print v "\trpms/2.1/" $0}'
    else
        $CURL "$V2_URL/deb/2.1/" 2>/dev/null \
        | grep -oE 'href="opensvc_2\.1-[0-9]+_all\.deb"' \
        | sed 's/href="//; s/"//' \
        | awk '{v=$0; sub(/^opensvc_/,"",v); sub(/_all\.deb$/,"",v); print v "\tdeb/2.1/" $0}'
    fi
}

write_v2() {
    local name=$1 flavor=$2 out=$WWW/v2/lab/svc/$name.json tmp
    tmp=$(mktemp)
    v2_versions "$flavor" | sort -t$'\t' -k1,1 -rV | head -n "$MAX" > "$tmp"
    {
        echo "["
        local first=1 ver path
        while IFS=$'\t' read -r ver path; do
            [ -z "$ver" ] && continue
            [ $first = 1 ] || echo ","
            first=0
            printf '  {"name": "%s", "value": "%s"}' "$ver" "$path"
        done < "$tmp"
        echo
        echo "]"
    } > "$tmp.json"
    rm -f "$tmp"
    install_file "$tmp.json" "$out" "v2 $name"
}

# move the new file in place only when its content changed (keeps the mtime meaningful)
install_file() {
    local src=$1 dst=$2 label=$3 n
    n=$(grep -c '"value"' "$src")
    [ "$n" -eq 0 ] && echo "$label: no package found, the list is empty" >&2
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        rm -f "$src"
        return 0
    fi
    chmod 644 "$src" && mv -f "$src" "$dst" || return 1
    echo "$label: $n packages -> $dst"
}

mkdir -p "$WWW/v3/lab/svc" "$WWW/v2/lab/svc" || exit 1
rc=0
for name in "${DISTROS[@]}"; do
    devrepo=${REPOS[$name]:-}
    [ -z "$devrepo" ] && { echo "$name: no repository in environment.sh, skipped" >&2; continue; }
    flavor=$(flavor_of "$name")
    write_v3 "$name" "$flavor" "$devrepo" || rc=1
    write_v2 "$name" "$flavor" || rc=1
done
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$WWW/last-refresh.txt"
exit $rc
