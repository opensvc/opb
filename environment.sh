DISTROS=("rhel7" "rhel8" "rhel9" "sles15" "u2004" "u2204" "u2404" "debian11" "debian12")
# does not work for sles12
# sles12 container image requires running on a sles12 registered system
# to act as a proxy to the rpm repositories

declare -A REPOS=( [rhel7]=dev-opensvc-v3-rhel7
	           [rhel8]=dev-opensvc-v3-rhel8
	           [rhel9]=dev-opensvc-v3-rhel9
	           [sles12]=dev-opensvc-v3-sles12
	           [sles15]=dev-opensvc-v3-sles15
	           [u2004]=dev-opensvc-v3-focal
	           [u2204]=dev-opensvc-v3-jammy
	           [u2404]=dev-opensvc-v3-noble
	           [debian11]=dev-opensvc-v3-bullseye
	           [debian12]=dev-opensvc-v3-bookworm
	         )
