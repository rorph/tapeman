#!/bin/bash

PROGNAME=$0
PID=$$
ME=BREAK
SHOWHELP=
PREFIX="split_"
SZ_LIMIT=
BASE=
DRY_RUN=

source $(dirname $(realpath $BASH_SOURCE))/include/common.sh

usage () {
    if [ -n "$*" ]; then
        message "usage error: $*"
    fi
    cat <<EOF
Usage: $PROGNAME [OPTION ...] ARGS ...
Options:
    -b, --base <base path>
    -s, --size maximum size in bytes
    -p, --prefix prefix for created folders
    --dry_run show stuff but do nothing
EOF
}

ARGS=$(getopt --options +b:s:p:h \
	--long base:,size:,prefix:,dry_run,help \
	--name "$PROGNAME" -- "$@")
GETOPT_STATUS=$?

if [ $GETOPT_STATUS -ne 0 ]; then
	error "internal error; getopt exited with status $GETOPT_STATUS"
	exit 6
fi

eval set -- "$ARGS"

while :; do
	case "$1" in
		-b|--base) BASE="$2"; shift ;;
		-s|--size) SZ_LIMIT="$2"; shift ;;
        -p|--prefix) PREFIX="$2"; shift ;;
        --dry_run) DRY_RUN="y" ;;
        -h|--help) SHOWHELP="y" ;;
		--) shift; break ;;
		*) log ERROR "Unknown option \"$1\" aborting"; exit 6 ;;
	esac
	shift
done

if [ "$SHOWHELP" -o -z "$BASE" -o -z "$SZ_LIMIT" ]; then
	usage
	exit 0
fi

if [ ! -d "$BASE" ]; then
    log ERROR "Invalid path: $BASE"
    exit 1
fi

if [ -z "$SZ_LIMIT" ]; then
    log ERROR "No Size set"
    exit 1
fi

if [ "$SZ_LIMIT" -le "0" ]; then
    log ERROR "Invalid size"
    exit 1
fi

for i in BASE SZ_LIMIT PREFIX DRY_RUN; do
    log INFO "-- $i: ${!i}"
done

SPLITS=0
TBYTES=0

while [ 1 ] ; do
    CSZ=0
    OBASE="${BASE}/${PREFIX}${SPLITS}/"

    for i in $(ls -1 --color=never "${BASE}"); do
        FN="${BASE}/$i"
        if [ -d "$FN" -o ! -f "$FN" ]; then
            continue
        fi
        
        FSZ=$(stat --printf="%s" "$FN")
        log TRACE "FSZ: $FSZ"
        if [ -z "$FSZ" ]; then
            log WARN "Skipping invalid file: ${FN}"
            continue
        fi

        TSZ=$((FSZ + CSZ))
        log TRACE "TSZ: $TSZ"
        
        if [ "$TSZ" -gt "$SZ_LIMIT" ]; then
            log TRACE "File: $FN overflows size limit: ${TSZ} vs ${SZ_LIMIT}, skipping"
            continue
        fi

        if [ ! -d "$OBASE" -a -z "$DRY_RUN" ]; then
            log TRACE "Creating: ${OBASE}"
            mkdir -p "${OBASE}"
        fi
        
        log DEBUG "Adding file: ${FN} to split: ${SPLITS}, ${FSZ} bytes, current bytes: ${CSZ}"
        if [ -z "$DRY_RUN" ]; then
            mv -v "${FN}" "${OBASE}"
            RT=$?
            if [ "$RT" -ne "0" ]; then
                log ERROR "Failed to move ${FN} to ${OBASE}, exiting"
                exit 1
            fi
        else
            log INFO "DRY_RUN enabled, Skipping move"
        fi

        CSZ=$((FSZ + CSZ))
    done

    if [ "$CSZ" -eq "0" ] ; then
        break
    fi

    TBYTES=$((CSZ + TBYTES))
    SPLITS=$((SPLITS + 1))

    log DEBUG "Total bytes: ${TBYTES} Splits: ${SPLITS} this loop: ${CSZ} bytes"

    if [ ! -z "$DRY_RUN" ]; then
        log INFO "DRY_RUN enabled, exiting loop"
        break
    fi
done

log INFO "-- Completed, ${SPLITS} splits, ${TBYTES} bytes."