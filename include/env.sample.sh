#!/bin/bash

# base path, automatic
declare -x BASE_PATH=$(dirname $(dirname $(realpath $BASH_SOURCE)))
# script absolute path
declare -x TAPEMAN="${BASE_PATH}/tapeman.sh"
# default database path
declare -x DATABASE="${BASE_PATH}/tapeman.db"
# use api instead of direct sqlite3 interaction
#declare -x DATABASE_API="https://tapeman.domain.ext/query"
# .. or leave blank to not use api
declare -x DATABASE_API=
# tape changer device path, leave blank for auto discovery
declare -x CHANGER=
# tape drive device path
declare -x MTDEV=/dev/nst0
# tape drive device id at changer
declare -x CHANGER_MTDEV_ID=1
# tape block size (must be in bytes); Your drive must support this size!
declare -x BLKSIZE=65536
# dd block size, must be a multiple of block size lower than tape drive maximum buffer size (must be in bytes)
# usualy the same of BLKSIZE
declare -x BS=65536
# mbuffer memory buffer size -- this will be stored in RAM
declare -x MBUFFER_SIZE=2G
# changer data transfer element regex
declare -x CHANGER_DTE="Data\sTransfer\sElement\s${CHANGER_MTDEV_ID}:"
# number of blocks to rollback when a error happens, if file is smaller than this, it will be clipped
# number of blocks = BLKSIZE * BRER bytes
declare -x BREB=10

# default path for automated scripts
declare -x BACKUP_ROOT=/path/to/storage