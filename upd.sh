#!/bin/bash

source /etc/init.d/functions.sh

ARGS="$@"
ARGCNT=$(echo "${ARGS}" | wc -w)

die() {
	eend $@
	exit 1
}

switch() {
	TATE=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | uniq)
	
	if [ "$TATE" != "powersave" ]; then
	ebegin "Switching to powersave mode"
	echo "powersave" | tee -a /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &> /dev/null
	eend $?
	fi
}

checks () {
	if [ "$(id -u)" -eq 0 ]
		then
		ebegin "Running as root" && eend
#		switch
		else
		eend "Please run this script as root user. Exiting."
		exit
	fi
	
	DEPS="eclean-dist updatedb"

	for DEP in $DEPS; do
		ebegin "Checking for ${DEP}" && [ "$(command -v ${DEP})" ] ; eend $? || die "Dependency ${DEP} not found."
	done

	ebegin "Checking for kgen.sh" && [ -f $PWD/kgen.sh ] ; eend $? || die "Not found kgen.sh"
}

sync () {
	emerge --sync
	eix-update
	eix-remote update
}

update () {
	emerge -DNvu --fetchonly @world
	emerge -DNvu --backtrack=100000000000 --keep-going --color=y @world
	flatpak update -y
}

gencache() {
	for REPO in $(ls /var/db/repos/ | sed "s/\///g"); do
		if ! [ ${REPO} = "musl" ]; then
			ebegin "Caching USE flag metadata for repository ${REPO}"
			egencache --verbose --jobs=$(nproc) --update --update-use-local-desc --repo ${REPO}
			eend $?
		fi
	done
}

cleanse () {
	emerge --depclean
	emerge @preserved-rebuild
	eclean-dist -d

	ebegin "Removing system logs"
	rm -rf /var/log/*
	eend $?

	ebegin "Reinitializing database"
	updatedb
	eend $?
}

normal() {
	clear
	checks && sync && update
	./kgen.sh
	gencache
	cleanse
	eselect news read
}

nosync() {
	clear
	checks && update
	./kgen.sh
	gencache
	cleanse
	eselect news read
}

[[ "$ARGCNT" -eq 0 ]] && normal
[[ "$ARGCNT" -eq 1 ]] && [[ "$ARGS" == "--nosync" ]] && nosync
[[ "$ARGCNT" -ne 0 ]] && [[ "$ARGCNT" -ne 1 ]] && die "Arguments are incorrect."
