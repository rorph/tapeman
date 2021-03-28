# TAPEMAN

This is a bash based system to manage LTO backups with an optional PHP API, queues and many other features.

Files and inventory sturcture is stored in a sqlite3 database.

The majority of components used in this project as POSIX compatible and should work in any linux based system.

The mains reason why I wrote this is to avoid highly annoying unnecessarily complex existing backups solutions.

## Dependencies

- sqlite3
- mbuffer
- php5+ (optional, for api)
- nginx (optional, for api)

## Setup

1. Copy `include/env.sample.sh` to `include/env.sh`, edit it with your own default settings
2. `chmod +x include/env.sh`

## Setup API backend

This is optional, but desired if you want to run tapeman in multiple machines with a unified database

1. If you want to run the PHP API backend, copy `include/config.sample.json` to `include/config.php` and edit it
2. Setup nginx, copy `etc/nginx/tapeman.sample.conf` to `etc/nginx/tapeman.conf` editing the root path

## Inventorizing

Before writing, you will need to run `--inventorize` to find all tapes and store their labels.

## Features

- Automatic changer discovery
- Automatic inventorizing
- Automatic load / unload
- Automatic seek / best fit
- Simple DD + MBUFFER streaming minimizing tape shoe shining
- Configurable block size 
- Support for optional HTTP based API
- SQLITE3 database, no daemons
- Queue capability

## Examples

### Add file to tape

```./tapeman.sh -i /path/to/file.ext --label tape_label```

### Queue a file

```./tapeman.sh --skip_setup --queue --label tape_label -i /path/to/file```

Use `--del` to delete queued file after queue has finished

### Run queue

```while [ 1 ]; do ./tapeman.sh --queue_check; sleep 30;done;```

### Fetch file from tape

```./tapeman.sh --fetch 1 -o /path/to/output```

Will fetch file id `1` from tape

### List files

```./tapeman.sh --list_files```

## Limitations / Warnings

- Concurrent multi-drive support
- LTOFS/TAPEFS - I run this on my LTO4 MSL4048, since I don't use LTOFS, this script wasn't test on it, it might just work ...
- This script will not work without a changer, or at least wasn't tested at all without one
- When DD fails, `tapeman` rolls back a few blocks and resume writing the file, this might not be supported by your drive, specially when automatic EOF blocks are enabled.

## TODO

- better file rotation
- postgres / mysql db backend
- pretty file listing
