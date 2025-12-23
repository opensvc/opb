DISTROS=("rhel7" "rhel8" "rhel9" "rhel10" "sles15" "sles16" "u2004" "u2204" "u2404" "debian12" "debian13")
# does not work for sles12
# sles12 container image requires running on a sles12 registered system
# to act as a proxy to the rpm repositories

declare -A REPOS=( [rhel7]=dev-opensvc-v3-rhel7
	           [rhel8]=dev-opensvc-v3-rhel8
	           [rhel9]=dev-opensvc-v3-rhel9
	           [rhel10]=dev-opensvc-v3-rhel10
	           [sles12]=dev-opensvc-v3-sles12
	           [sles15]=dev-opensvc-v3-sles15
	           [sles16]=dev-opensvc-v3-sles16
	           [u2004]=dev-opensvc-v3-focal
	           [u2204]=dev-opensvc-v3-jammy
	           [u2404]=dev-opensvc-v3-noble
	           [debian13]=dev-opensvc-v3-trixie
	           [debian12]=dev-opensvc-v3-bookworm
	         )
