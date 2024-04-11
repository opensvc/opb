# OpenSVC Package Builder 

## aim
- build OpenSVC software packages for operating systems

## organisation
- docker folder contains stuff needed to build multi-os environments
- tools folder contains package building automation

## constraints
- multi os support
- multi stage images
  * populate /opt in first stage
  * avoid go modules to be downloaded at each container instanciation
  * won't prevent rpmbuild/debianhelper to download them during package build
- allow per os custom binary build (dynamic binaries, debug binaries, ...)
- ready to use development environment for specific distro troubleshoot
- package build from any git commit id, git branch, github pull request

## prerequisites
- docker/podman
- for enterprise grade distribution, credentials are needed for register

## getting started
- review/update environment.sh file
- if needed, create docker/credentials.txt (based on docker/credentials.template.txt)
- run go.sh -h               # display help
- run go.sh -r -b -q xxxx    # build os xxxx container image
- run go.sh -r -p -q xxxx    # build opensvc package on latest git commit id

## todo
- option static/dynamic
- pkg sign
- improve version test on binaries
- webapp integration
- 2.1 to 3 upg (transitional package)
- test commit id in deb build
- check makefile use
