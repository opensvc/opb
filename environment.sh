DISTROS=("rhel7" "rhel8" "rhel9" "sles15" "u2204" "debian12")
# does not work for sles12
# sles12 container image requires running on a sles12 registered system
# to act as a proxy to the rpm repositories

ARCH=$(arch)

declare -A REPOS=( [rhel7]=opensvc-3-rhel7-$ARCH-dev
	           [rhel8]=opensvc-3-rhel8-$ARCH-dev
	           [rhel9]=opensvc-3-rhel9-$ARCH-dev
	           [sles15]=opensvc-3-sles15-$ARCH-dev
	           [u2004]=opensvc-3-ubuntu2004-$ARCH-dev
	           [u2204]=opensvc-3-ubuntu2204-$ARCH-dev
	           [u2404]=opensvc-3-ubuntu2404-$ARCH-dev
	           [debian12]=opensvc-3-bookworm-$ARCH-dev
	         )
