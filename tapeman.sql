PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS "inventory" (
    "label"	TEXT NOT NULL UNIQUE,
    "type"	TEXT NOT NULL DEFAULT 'Unknown',
    "added"	NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "used"	NUMERIC DEFAULT CURRENT_TIMESTAMP,
    "blocks_written"	NUMERIC NOT NULL DEFAULT 0,
    "notes" TEXT,
    "is_cleaning" INTEGER NOT NULL DEFAULT 0,
    "wasted" INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY("label")
);

CREATE TABLE IF NOT EXISTS "type_size" (
    "type"	TEXT NOT NULL UNIQUE,
    "byte_size"  NUMERIC NOT NULL DEFAULT 0,
    PRIMARY KEY("type")
);

CREATE TABLE IF NOT EXISTS "files" (
    "file_id"	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    "label"	TEXT NOT NULL,
    "filename"	TEXT NOT NULL,
    "hash"	TEXT NOT NULL,
    "byte_size"	INTEGER NOT NULL DEFAULT 0,
    "block_size" INTEGER NOT NULL DEFAULT 0,
    "block_start"	INTEGER NOT NULL DEFAULT 0,
    "block_end"	INTEGER NOT NULL DEFAULT 0,
    "added"	NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "wasted" INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (label) REFERENCES inventory(label)
);

CREATE TABLE IF NOT EXISTS "label_groups" (
	"group_id"	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
	"name"	TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "rel_inventory" (
    "label"	TEXT NOT NULL,
    "group_id" INTEGER NOT NULL,
    FOREIGN KEY (label) REFERENCES inventory(label),
    FOREIGN KEY (group_id) REFERENCES label_groups(group_id)
);

CREATE TABLE IF NOT EXISTS "queue" (
    "queue_id"    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    
    -- 0 = waiting
    -- 1 = running
    -- 2 = completed
    -- 3 = error
    "status"	INTEGER NOT NULL DEFAULT 0,
    
    -- label1[,label2,..,labelN]
    "label" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    
    -- -1 = auto
    -- >= 0 specific
    "tell"	INTEGER NOT NULL DEFAULT -1,

    "del"	INTEGER NOT NULL DEFAULT 0,
    "added"	NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ran"	NUMERIC DEFAULT NULL
);

PRAGMA foreign_keys = ON;

INSERT INTO `type_size` (`type`, `byte_size`) VALUES ("LTO-4", "800000000000");