#!/bin/bash 

source $(dirname $(realpath $BASH_SOURCE))/env.sh

log () {
    ERROR='\033[1;31m'
    INFO='\033[1;32m'
    WARN='\033[1;33m'
    TRACE='\033[1;35m'
    DEBUG='\033[1;36m'
    SQL='\033[1;34m'
    C_N='\033[0m'
    level=INFO
    
    if [ -n "$1" ] ; then
        level=$1
		IN="${@:2}"
	else
		read IN
	fi
	
	echo -e ${C_N}${!level}[$(date +%y%m%d@%H:%M:%S):$$:$ME] $level $IN${C_N}
}

gen_tar_name() {
    OFN="$BACKUP_ROOT"/"$1"-$(date +%y%m%d).tar.gz
}

for i in BASE_PATH TAPEMAN DATABASE DATABASE_API BACKUP_ROOT; do
    log TRACE "-- ${i}: ${!i}"
done