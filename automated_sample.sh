#!/bin/bash

# example of a cron activated backup

source $(dirname $(realpath $BASH_SOURCE))/include/common.sh

gen_tar_name backup_name
declare -x OFN="$OFN"

tar -czvf "${OFN}" /path/to/input && \
    $TAPEMAN -i "${OFN}" --skip_setup --del --queue --label tape_label1,tape_label2

