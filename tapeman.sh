#!/bin/bash
# (c) z3n - R1V1@201218 - www.overflow.biz - rodrigo.orph@gmail.com

PROGNAME=$0
PID=$$
ME=TMAN
INPUT_FILE=
OUTPUT_FILE=
MTDEV_STATUS=
MTDEV_MEDIA_TYPE=
MTDEV_MEDIA_LOADED=
MTDEV_MEDIA_SOURCE=
MTDEV_MEDIA_LABEL=
MTDEV_MEDIA_TELL=
INPUT_FILE_START=
INPUT_FILE_END=
SKIP=0
RSKIP=0
SEEK=
FETCH=
QRESULT=
DRY_RUN=
QUEUE=
QUEUE_CHECK=
QUEUE_ID=
DEL_INPUT=
SKIP_SETUP=
SKIP_UNLOAD=
LIST_FILES=
LIST_INVENTORY=
FETCH_LABEL=
FETCH_HASH=
BT=50
NOSLEEP=
#LOG_PID=
LOG_OUT=

TMP_OUT=$(mktemp)
TMP_DB=$(mktemp --suffix=.db)

source $(dirname $(realpath $BASH_SOURCE))/include/common.sh

function ceiling {
    DIVIDEND=${1}
    DIVISOR=${2}
    if [ $(( DIVIDEND % DIVISOR )) -gt 0 ]; then
            RESULT=$(( ( ( $DIVIDEND - ( $DIVIDEND % $DIVISOR ) ) / $DIVISOR ) + 1 ))
    else
            RESULT=$(( $DIVIDEND / $DIVISOR ))
    fi
    echo $RESULT
}

mtchg_find () {
    log INFO "-- Changer auto discovery..."
    for i in $(ls --color=never -1 /dev/sg*); do
        mtx -f $i status &> /dev/null
        RT=$?
        if [ "$RT" -eq "0" ]; then
            log INFO "-- Found changer at $i"
            CHANGER=$i
            break
        fi
    done

    if [ -z "$CHANGER" ]; then
        log ERROR "No changer found, aborting!"
        clean_exit
    fi
}

mtchg_status () {
    if [ -z "$CHANGER" ]; then
        mtchg_find
    fi

    log INFO "-- Collecting status on changer: ${CHANGER}..."
    mtx -f ${CHANGER} status &> $TMP_OUT
    check_exit $?
    if [ "$(cat $TMP_OUT | grep "${CHANGER_DTE}" | cut -d':' -f2)" == "Empty" ] ; then
        log INFO "-- No media loaded on $CHANGER_DTE"
        MTDEV_MEDIA_LOADED="n"
    else
        MTDEV_MEDIA_LOADED="y"
        MTDEV_MEDIA_SOURCE=$(cat $TMP_OUT | grep "${CHANGER_DTE}" | cut -d':' -f2 | cut -d' ' -f4)
        MTDEV_MEDIA_LABEL=$(cat $TMP_OUT | grep "${CHANGER_DTE}" | cut -d':' -f3 | cut -d' ' -f3)
        log INFO "-- Media src: $MTDEV_MEDIA_SOURCE label: $MTDEV_MEDIA_LABEL"
    fi
}

mtdev_status() {
    log INFO "-- ${MTDEV} status..."
    
    mt -t ${MTDEV} status &> /dev/null
    mt -t ${MTDEV} status &> $TMP_OUT
    out=$(cat $TMP_OUT)
    
    if [[ "$out" == *"resource busy"* ]]; then
        log WARN "Device is busy"
        MTDEV_STATUS="busy"
    else
        log INFO "$out"
        MTDEV_MEDIA_TYPE=$(cat $TMP_OUT | grep Density | cut -d '(' -f2- | cut -d')' -f1)
        MTDEV_STATUS="ready"
    fi
}

mtdev_unload () {
    if [ "$MTDEV_MEDIA_LOADED" == "n" ]; then
        log TRACE "-- No media loaded, skipping unload"
        return
    fi
    if [ ! -z "$DRY_RUN" ]; then
        return
    fi
    if [ -z "$CHANGER" ]; then
        mtchg_find
    fi

    mtx -f ${CHANGER} status &> $TMP_OUT
    check_exit $?
    mt -t ${MTDEV} unlock
    check_exit $?
    mt -t ${MTDEV} seek 0
    check_exit $?
    UELM=$(cat $TMP_OUT | grep "${CHANGER_DTE}" | cut -d' ' -f7)
    log TRACE "-- ${CHANGER} Unloading element $UELM from $CHANGER_MTDEV_ID"
    mtx -f ${CHANGER} unload $UELM $CHANGER_MTDEV_ID
    check_exit $?
}

mtdev_load () {
    LLABEL="$1"
    if [ "$MTDEV_MEDIA_LABEL" == "$LLABEL" ]; then
        return
    fi
    if [ -z "$CHANGER" ]; then
        mtchg_find
    fi
    
    log INFO "-- Loading ${LLABEL}..."
    
    # find tape to load
    mtx -f ${CHANGER} status &> $TMP_OUT
    check_exit $?
    LELM=$(cat $TMP_OUT | grep -vE "Data Transfer|Storage Changer" | grep "Storage Element" | grep $LLABEL | sed -e 's/^[ \t]*//' | cut -d' ' -f3 | cut -d':' -f1)

    if [ ! -z "$MTDEV_MEDIA_LABEL" ]; then
        mtdev_unload
    fi

    log TRACE "-- ${CHANGER} Loading element $LELM into $CHANGER_MTDEV_ID"
    
    if [ -z "$DRY_RUN" ]; then
        mtx -f ${CHANGER} load $LELM $CHANGER_MTDEV_ID
        check_exit $?
    fi
    
    mtchg_status
    mtdev_ready_wait
    mtdev_status
    mtdev_setup
}

mtdev_tell () {
    log INFO "-- ${MTDEV} tell..."
    mt -t ${MTDEV} tell &> $TMP_OUT
    check_exit $?
    MTDEV_MEDIA_TELL=$(cat $TMP_OUT | cut -d' ' -f3 | cut -d'.' -f1)
    log INFO "-- ${MTDEV} at block ${MTDEV_MEDIA_TELL}"
}

mtdev_seek () {
    log INFO "-- ${MTDEV} seeking to $1"
    mt -t ${MTDEV} seek $1
    check_exit $?
}

mtdev_setup () {
    if [ "$MTDEV_MEDIA_LOADED" == "n" ]; then
        log TRACE "-- No media loaded, skipping setup"
        return
    fi

    log INFO "-- $MTDEV blksize $BLKSIZE"
    mt -f $MTDEV setblk $BLKSIZE
    log INFO "-- $MTDEV compression"
    mt -f $MTDEV defcompression 1
    mt -f $MTDEV compression 1
    mt -f $MTDEV drvbuffer 1

    mtdev_tell
}

mtdev_ready_wait () {
    mtdev_status
    
    while [ "$MTDEV_STATUS" == "busy" ] ; do
        log INFO "-- ${MTDEV} is busy, waiting..."
        sleep 30
        mtdev_status
    done

    log INFO "-- ${MTDEV} ready"
}

dry_run_exit () {
    if [ -n "$DRY_RUN" ]; then
        log WARN "-- Dry run enabled, exiting"
        kill $PID
        exit 0
    fi
}

check_exit () {
    RT=$1
    if [ "$RT" -ne "0" ]; then
        log WARN "-- Exit code: $RT"
        log ERROR "Error, aborting"
        #if [ ! -z "$LOG_PID" ]; then
        #    kill -9 ${LOG_PID}
        #fi
        if [ ! -z "$LOG_OUT" ]; then
            rm -f "${LOG_OUT}"
        fi

        kill $PID
        exit 1
    fi
}

sql () {
    log SQL "$@"
    if [ -z "$DATABASE_API" ]; then
        QRESULT=$(sqlite3 ${TMP_DB} "$@")
    else
        curl -vvv -X POST $DATABASE_API -d "q=$@" -o $TMP_DB &> /dev/null
        QRESULT=$(cat $TMP_DB)
    fi
}

clean_exit () {
    if [ -z "$DATABASE_API" ] ; then
        log DEBUG "-- Copying ${TMP_DB} -> ${DATABASE}"
        cp "${TMP_DB}" "${DATABASE}"
    fi

    #if [ ! -z "$LOG_PID" ]; then
    #    kill -9 ${LOG_PID} &> /dev/null
    #fi
    
    if [ ! -z  "$LOG_OUT" ]; then
        rm -f  "${LOG_OUT}" &> /dev/null
    fi
    
    rm -f ${TMP_OUT} ${TMP_DB} &> /dev/null
    if [ -z "$NOSLEEP" ] ; then
        rm -f /tmp/nosleep
    fi
}

usage () {
    if [ -n "$*" ]; then
        message "usage error: $*"
    fi
    cat <<EOF
Usage: $PROGNAME [OPTION ...] ARGS ...
Options:
	-x, --changer <dev> path to changer dev
	-f, -t, --mt <dev> path to mt dev
    -b, --blk <size> block size
    -m, --mbuffer <size> mbuffer memory size
    -i, --input <path/to/file> input file
    -s, --skip <value> Skip a number of blocks in the input
    -k, --seek <value> Seek tape to a certain position before writing
    -d, --db <path/to/file.db> path to db file
    --bs <block size> for dd, must be a multiple of tape's block size
    --bt <percent> buffer fill threshold
    --fetch <id> get file id from database
    -r, --block_error_rollback <int> blocks to roll back when a writing error happens
    -o, --output <path/to/file> Path to output file, when doing --fetch
    --inventorize Add tapes from changes to inventory
    --queue Queue operation instead of running it
    --queue_check Run pending queues
    --label One or more tape labels
    --force Force device inventory run
    --list List inventory
    --list_files list files
    --del Remove input after writting
    --skip_setup Skips changer setups, ideal for queuing on a different machine
    --skip_unload Skips tape auto unloading after executing a queue entry
    --dry_run show stuff but do nothing
EOF
}

ARGS=$(getopt --options +x:f:t:i:m:d:s:k:o:r:h \
	--long changer:,mt:,blksize:,input:,mbuffer:,db:,seek:,skip:,bs:,inventorize,force,output:,fetch:,help,dry_run,block_error_rollback:,queue_check,queue,label:,del,skip_setup,list,list_files,bt:,skip_unload \
	--name "$PROGNAME" -- "$@")
GETOPT_STATUS=$?

if [ $GETOPT_STATUS -ne 0 ]; then
	error "internal error; getopt exited with status $GETOPT_STATUS"
	exit 6
fi

eval set -- "$ARGS"

while :; do
	case "$1" in
		-x|--changer) CHANGER="$2"; shift ;;
		-f|-t|--mt) MTDEV="$2"; shift ;;
        -b|--blksize) BLKSIZE="$2"; shift ;;
        --bs) BS="$2"; shift ;;
        --bt) BT="$2"; shift ;;
        -m|--mbuffer) MBUFFER_SIZE="$2"; shift ;;
        -d|--db) DATABASE="$2"; shift ;;
        -i|--input) INPUT_FILE="$2"; shift ;;
        --fetch) FETCH="$2"; shift ;;
        --queue) QUEUE="y" ;;
        --queue_check) QUEUE_CHECK="y" ;;
        --skip_setup) SKIP_SETUP="y" ;;
        --skip_unload) SKIP_UNLOAD="y" ;;
        --del) DEL_INPUT="y" ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        -r|--block_error_rollback) BERB="$2"; shift ;;
        -s|--skip) SKIP="$2"; shift ;;
        -k|--seek) SEEK="$2"; shift ;;
        --label) FETCH_LABEL="$2"; shift ;;
		-h|--help) SHOWHELP="yes" ;;
        --inventorize) INVENTORIZE="yes" ;;
        --list) LIST_INVENTORY="yes" ;;
        --list_files) LIST_FILES="yes" ;;
        --force) INVENTORIZE_FORCE="yes" ;;
        --dry_run) DRY_RUN="y" ;;
		--) shift; break ;;
		*) log ERROR "Unknown option \"$1\" aborting"; exit 6 ;;
	esac
	shift
done

if [ "$SHOWHELP" ]; then
	usage
	exit 0
fi

for i in CHANGER MTDEV BLKSIZE INPUT_FILE MBUFFER_SIZE DATABASE; do
    log INFO "-- $i: ${!i}"
done

if [ -z "$DATABASE_API" ]; then
    if [ ! -f "$DATABASE" ] ; then
        log WARN "-- Database: $DATABASE doesnt exist, creating a new one..."
        sqlite3 ${TMP_DB} < tapeman.sql
    else
        cp "${DATABASE}" "${TMP_DB}"
    fi
fi

if [ "$INVENTORIZE_FORCE" ]; then
    log INFO "-- Running inventory on ${CHANGER}..."
    mtx -f ${CHANGER} inventory
    check_exit $?
fi
if [ "$INVENTORIZE" ]; then
    log INFO "-- Inventorizing ${CHANGER}..."
    mtchg_status
    
    #cat $TMP_OUT | grep VolumeTag | cut -d'=' -f2 | sed -e 's/^[ \t]*//' | xargs -n1 -P1 -I'{}' sqlite3 ${TMP_DB} "insert into inventory (label) values (TRIM(\"{}\"));"
    #cat $TMP_OUT | grep VolumeTag | cut -d'=' -f2 | sed -e 's/^[ \t]*//' | xargs -n1 -P1 -I'{}' sql "insert into inventory (label) values (TRIM(\"{}\"));"
    cat $TMP_OUT | grep VolumeTag | cut -d'=' -f2 | sed -e 's/^[ \t]*//' >> "$TMP_OUT".2
    
    while IFS= read -r line; do
        sql "insert into inventory (label) values (TRIM(\"$line\"));"
    done < "$TMP_OUT".2
    rm -f "$TMP_OUT".2
    LIST_INVENTORY="yes"
fi

if [ -n "$LIST_INVENTORY" ]; then
    log INFO "-- Listing inventory:"
    sql "select label from inventory"
    log INFO $QRESULT
    exit 0
fi

if [ -n "$LIST_FILES" ]; then
    log INFO "-- Listing Files:"
    sql "select * from files"
    log INFO $QRESULT
    exit 0
fi

if [ -z "$SKIP_SETUP" ]; then
    mtchg_status
    if [ -z "$QUEUE_CHECK" ]; then
        if [ ! -z "$FETCH_LABEL" -a "$MTDEV_MEDIA_LOADED" != "$FETCH_LABEL" ]; then
            mtdev_load $FETCH_LABEL
        elif [ "$MTDEV_MEDIA_LOADED" == "n" -a -z "$FETCH" ]; then
            if [ -z "$FETCH_LABEL" ] ; then
                log ERROR "No tape loaded and no tape defined to write, exiting..."
                exit 1
            fi
            mtdev_load $FETCH_LABEL
        fi
        
        mtdev_ready_wait
        mtdev_setup
    fi
fi

### WILL READ FROM TAPE #######################################################

if [ ! -z "$FETCH" ]; then
    sql "select label from files where file_id = $FETCH limit 1"
    FETCH_LABEL=$QRESULT
    sql "select block_start from files where file_id = $FETCH limit 1"
    FETCH_TELL=$QRESULT
    sql "select block_size from files where file_id = $FETCH limit 1"
    FETCH_BLKSIZE=$QRESULT
    log INFO "-- Fetch label: $FETCH_LABEL tell: $FETCH_TELL blksize: $FETCH_BLKSIZE"
    BLKSIZE=$FETCH_BLKSIZE
    
    if [ -z "$OUTPUT_FILE" ]; then
        log ERROR "-- No output file set, aborting"
        clean_exit
        exit 1
    fi

    mtdev_load $FETCH_LABEL
    mtdev_setup

    dry_run_exit
    if [ -f "/tmp/nosleep" ]; then
        NOSLEEP=1
        touch /tmp/nosleep
    fi
    LOG_OUT=$(mktemp --suffix=.log)

    while [ 1 ]; do
        mtdev_seek ${FETCH_TELL}

        #dd if=${MTDEV} bs=${BS} conv=notrunc,sync status=progress of=${OUTPUT_FILE}
        dd if=${MTDEV} bs=${BS} conv=notrunc,sync | mbuffer -m ${MBUFFER_SIZE} -L -l ${LOG_OUT} -H -P ${BT} -s ${BS} >> ${OUTPUT_FILE}
        RT=$?
        
        if [ "$RT" -eq "0" ]; then
            break
        fi

        log ERROR "-- Error copying file, retrying..."
        rm -f ${OUTPUT_FILE} &> /dev/null
    done
    GOT_HASH=$(cat ${LOG_OUT} | grep "MD5 hash:" | cut -d':' -f2 | cut -d' ' -f2-)
    log INFO "-- Completed, db hash: ${FETCH_HASH} fetched hash: ${GOT_HASH}"
    if [ -z "$SKIP_UNLOAD" ]; then
        log INFO "-- Unloading tape"
        mtdev_unload
    fi
    
    clean_exit
    exit 0
fi

### WILL FETCH QUEUED OPERATION AND RUN #######################################

if [ ! -z "$QUEUE_CHECK" ]; then
    sql "select queue_id from queue where status = 0 order by added asc limit 1"
    
    if [ -z "$QRESULT" ] ; then
        log WARN "-- Nothing queued, exiting"
        clean_exit
        exit 0
    fi
    
    QUEUE_ID=$QRESULT
    log INFO "-- Running queue #${QUEUE_ID}"
    mtdev_status
    if [ -z "$DRY_RUN" ]; then
        sql "update queue set status = 1 where queue_id=${QUEUE_ID}"
    fi
    
    sql "select filename from queue where queue_id=${QUEUE_ID} limit 1"
    INPUT_FILE="$QRESULT"
    
    sql "select tell from queue where queue_id=${QUEUE_ID} limit 1"
    SEEK="$QRESULT"
    
    sql "select del from queue where queue_id=${QUEUE_ID} limit 1"
    if [ "$QRESULT" -eq "1" ] ; then
        DEL_INPUT="y"
    fi
    
    sql "select label from queue where queue_id=${QUEUE_ID} limit 1"
    FETCH_LABEL=$(echo "$QRESULT" | sed -e 's/,/","/g')
    sql "select label from inventory where label in (\"${FETCH_LABEL}\") order by used ASC limit 1"
    FETCH_LABEL="$QRESULT"
    sql "select hash from inventory where label in (\"${FETCH_LABEL}\") order by used ASC limit 1"
    FETCH_HASH="$QRESULT"
    
    log DEBUG "-- File: ${INPUT_FILE} Label: ${FETCH_LABEL} Tell: ${SEEK}"

    dry_run_exit

    mtdev_load $FETCH_LABEL
    mtdev_setup
fi

### WILL WRITE TO TAPE ########################################################

if [ -z "$INPUT_FILE" -o ! -f "$INPUT_FILE" ]; then
    log ERROR "Invalid / missing input file parameter"
    
    if [ ! -z "$QUEUE_ID" ]; then
        log WARN "Failing queue #${QUEUE_ID}"
        sql "update queue set status = 3 where queue_id=${QUEUE_ID}"
    fi

    usage
    clean_exit
    exit 0
fi

### WILL QUEUE OP #############################################################

if [ ! -z "$QUEUE" ]; then
    if [ -z "$FETCH_LABEL" ]; then
        log ERROR "No labels defined, aborting"
        clean_exit
        exit 0
    fi
    log INFO "-- Queuing op"
    
    if [ -z "$DEL_INPUT" ]; then
        DEL_INPUT=0
    else
        DEL_INPUT=1
    fi
    if [ -z "$SEEK" ]; then
        SEEK=-1
    fi

    sql "insert into queue (label, filename, tell, del) values (\"${FETCH_LABEL}\", \"${INPUT_FILE}\", ${SEEK}, ${DEL_INPUT})"
    clean_exit
    exit 0
fi

FILE_BYTE_SIZE=$(wc -c ${INPUT_FILE} | cut -d' ' -f1)
FILE_BLOCK_SIZE=$(ceiling $FILE_BYTE_SIZE $BS)

sql "SELECT byte_size from type_size where type=\"${MTDEV_MEDIA_TYPE}\" limit 1"
MEDIA_BYTE_SIZE=$QRESULT
MEDIA_BLOCK_SIZE=
if [ ! -z "$MEDIA_BYTE_SIZE" ]; then
    MEDIA_BLOCK_SIZE=$(ceiling $MEDIA_BYTE_SIZE $BS)
    log DEBUG "-- Media byte size: ${MEDIA_BYTE_SIZE} blocks: ${MEDIA_BLOCK_SIZE}"
fi

# try to automatically allocate file on free / oldest space at tape
if [ "$SEEK" == "-1" ]; then
    if [ -z "$FETCH_LABEL" ]; then
        log ERROR "No labels defined, cannot auto seek. Aborting"
        clean_exit
        exit 0
    fi

    if [ ! -z "$MEDIA_BLOCK_SIZE" ]; then
        sql "select block_end from files where label = \"$FETCH_LABEL\" order by block_end DESC limit 1"
        SEEK=$QRESULT
        if [ ! -z "$SEEK" -a "$((SEEK + FILE_BLOCK_SIZE))" -le "$MEDIA_BLOCK_SIZE" ]; then
            log INFO "-- Appending to tape at block $SEEK"
        else
            SEEK=-1
        fi
    fi

    if [ "$SEEK" == "-1" ]; then
        sql "select block_start from files where label = \"$FETCH_LABEL\" and (block_end - block_start) >= ${FILE_BLOCK_SIZE} order by added ASC limit 1"
        SEEK=$QRESULT
        if [ -z "$SEEK" ]; then
            SEEK=0
        fi
    fi
fi

if [ ! -z "$SEEK" ]; then
    mtdev_seek ${SEEK}
fi

mtdev_tell
INPUT_FILE_START=${MTDEV_MEDIA_TELL}

if [ "$FILE_BLOCK_SIZE" -lt "$BREB" ]; then
    log WARN "-- File block size is less than error rollback, clipping rollback to $FILE_BLOCK_SIZE"
    BREB=$FILE_BLOCK_SIZE
fi

# estimate block usage
INPUT_FILE_END=$((INPUT_FILE_START + FILE_BLOCK_SIZE + 2))

# check for conflicts
sql "select count(*) from files where label=\"${MTDEV_MEDIA_LABEL}\" and block_start >= ${INPUT_FILE_START} and block_end <= ${INPUT_FILE_END}"

if [ "$QRESULT" -gt "0" ] ; then
    log WARN "-- $QRESULT files will be overwritten and lost:"
    sql "select \* from files where label=\"${MTDEV_MEDIA_LABEL}\" and block_start >= ${INPUT_FILE_START} and block_end <= ${INPUT_FILE_END}"
    log INFO $QRESULT
    log WARN "-- WILL CONTINUE IN 5 SECONDS, PRESS CTRL+C TO ABORT NOW..."
    sleep 5
fi

log INFO "-- Writing: ${INPUT_FILE} to ${MTDEV} starting at block: ${INPUT_FILE_START} block size: ${BS} blocks to write: ${FILE_BLOCK_SIZE}..."

dry_run_exit
if [ -f "/tmp/nosleep" ]; then
    NOSLEEP=1
    touch /tmp/nosleep
fi

mtdev_tell
check_exit $?
LAST_TELL=$MTDEV_MEDIA_TELL
LOG_OUT=$(mktemp --suffix=.log)

while [ 1 ] ; do
    # this works, however, depending on the compression it will shoe shine, having a buffer has proven useful
    #dd if=${INPUT_FILE} status=progress skip=$RSKIP bs=${BS} of=${MTDEV}
    cmd="dd if=${INPUT_FILE} skip=$RSKIP bs=${BS} conv=notrunc,sync | mbuffer -m ${MBUFFER_SIZE} -H -L -P ${BT} -s ${BS} >> ${MTDEV}"
    log DEBUG $cmd
    #tail -fq ${LOG_OUT} &
    #LOG_PID=$!
    dd if=${INPUT_FILE} skip=$RSKIP bs=${BS} conv=notrunc,sync | mbuffer -m ${MBUFFER_SIZE} -H -l ${LOG_OUT} -L -P ${BT} -s ${BS} >> ${MTDEV}
    
    # using -s 2M would work, however, if tape fails mbuffer will not be able to resume the process
    #mbuffer -m ${MBUFFER_SIZE} -L -P 50 -s ${BS} -i ${INPUT_FILE} -o ${MTDEV}
    RT=$?
    
    if [ "$RT" -eq "0" ]; then
        break
    fi

    mtdev_tell
    check_exit $?

    #if [ "$MTDEV_MEDIA_TELL" -lt "$LAST_TELL" ]; then
    #    log ERROR "Last tell greater than current tell, something is wrong. $LAST_TELL vs $MTDEV_MEDIA_TELL , aborting"
    #    clean_exit
    #    exit 1
    #fi

    WBLOCKS=$((MTDEV_MEDIA_TELL - INPUT_FILE_START))
    log TRACE "SKIP: $SKIP RSKIP: $RSKIP LAST_TELL: $LAST_TELL TELL: $MTDEV_MEDIA_TELL START: $INPUT_FILE_START WBLOCKS: $WBLOCKS"
    LAST_TELL=$MTDEV_MEDIA_TELL

    if [ "$WBLOCKS" -ge "$FILE_BLOCK_SIZE" ] ; then
        log TRACE "Looks like all blocks were written, wrote: $WBLOCKS expected: $FILE_BLOCK_SIZE"
        break
    fi

    # there was an error, rollback by $BREB blocks
    RSKIP=$((SKIP + MTDEV_MEDIA_TELL - INPUT_FILE_START - BREB))
    MTDEV_MEDIA_TELL=$((MTDEV_MEDIA_TELL - BREB))
    
    # clip to avoid going negative
    if [ "$RSKIP" -lt "0" ]; then
        RSKIP=0
    fi
    if [ "$MTDEV_MEDIA_TELL" -lt "0" ]; then
        MTDEV_MEDIA_TELL=0
    fi
    
    # seek media back
    mt -f ${MTDEV} seek $MTDEV_MEDIA_TELL
    log ERROR "-- Error, resuming writing from $RSKIP starting at block $MTDEV_MEDIA_TELL ..."
    
    LAST_TELL=$((LAST_TELL - BREB))
    if [ "$LAST_TELL" -lt "0" ]; then
        LAST_TELL=0
    fi


done

# it doesn't look like this is needed, eof seem to be added automatically
#log INFO "-- Write completed, weof..."
#mt -f ${MTDEV} weof

mtdev_tell
INPUT_FILE_END=${MTDEV_MEDIA_TELL}
log INFO "-- Finished writing, ending block: ${INPUT_FILE_END}"
if [ ! -z "${LOG_OUT}" ]; then
    INPUT_FILE_HASH=$(cat ${LOG_OUT} | grep "MD5 hash:" | cut -d':' -f2 | cut -d' ' -f2-)
    log INFO "-- Hash from MBUFFER: ${INPUT_FILE_HASH}..."
else
    log INFO "-- Hashing..."
    INPUT_FILE_HASH=$(sha1sum ${INPUT_FILE} | cut -d' ' -f1)
fi
log INFO "-- ${INPUT_FILE}: ${INPUT_FILE_HASH}"

if [ ! -z "$DEL_INPUT" ]; then
    log INFO "-- Removing ${INPUT_FILE}..."
    rm -f ${INPUT_FILE} &> /dev/null &
fi

log INFO "-- Updating database"

# if any, remove conflicting files, since they been overwritten
sql "delete from files where label=\"${MTDEV_MEDIA_LABEL}\" and ((block_start between ${INPUT_FILE_START}+1 and ${INPUT_FILE_END}) or (block_end between ${INPUT_FILE_START}+1 and ${INPUT_FILE_END}))"
# add new file
sql "insert into files (label, filename, hash, byte_size, block_size, block_start, block_end, wasted) values (\"${MTDEV_MEDIA_LABEL}\", \"${INPUT_FILE}\", \"${INPUT_FILE_HASH}\", ${FILE_BYTE_SIZE}, ${BLKSIZE}, ${INPUT_FILE_START}, ${INPUT_FILE_END}, ${SECONDS})"
# update tape status
sql "update inventory set blocks_written=blocks_written+${FILE_BLOCK_SIZE},wasted=wasted+${SECONDS},used=CURRENT_TIMESTAMP where label=\"${MTDEV_MEDIA_LABEL}\""
# show result
sql "select label, filename, hash, byte_size, block_size, block_start, block_end from files where hash = \"${INPUT_FILE_HASH}\""
log INFO $QRESULT

if [ ! -z "$QUEUE_ID" ]; then
    log INFO "-- Completing queue #${QUEUE_ID}"
    sql "update queue set status=2,ran=CURRENT_TIMESTAMP where queue_id=${QUEUE_ID}"
    if [ -z "$SKIP_UNLOAD" ]; then
        log INFO "-- Unloading..."
        mtdev_unload
    else
        log INFO "-- Unloading disabled"
    fi
fi

log INFO "-- Completed"

clean_exit
