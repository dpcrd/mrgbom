#!/usr/bin/bash

# Synopsis: import BOM CSV files into a SQLite database, merge them, export the data.

# this script absolute path, with no trailing slash:
SRC_DIR=${0%$(basename $0)}
SRC_DIR=${SRC_DIR%/}

# source SQL snippets:
SQL_CREATE_TABLE=$SRC_DIR/create-table.sql
SQL_CREATE_VIEW=$SRC_DIR/create-view.sql

# SQL script generated to create a database that fits the number of BOMs:
SQL_SCRIPT=mrgbom.sql

# database created:
DBNAME=mrgbom.sqlite3

# import operations are logged and timestamped:
LOGFILE=mrgbom.log

function usage()
{
	echo "Usage: $(basename $0) [OPTIONS]"
	echo "Import BOMs from several PCBs into an SQLite database to merge them: sum the"
	echo "quantities, insert mate parts as new entries. The result can be exported to"
	echo "a CSV file."
	echo
	echo "Options:"
	echo "  -f               Try to find BOMs in subdirectories 'bom/' (case insensitive),"
	echo "                   print to stdout and exit."
	echo "  -i BOMLIST       Create the database $DBNAME, overwritting any existing copy."
	echo "                   Import the CSV files into the database listed in BOMLIST,"
	echo "                   a text file, containing one file name per line. Allowed"
	echo "                   characters in file names are letters, numbers, hyphen"
	echo "                   and underscore."
	echo "  -e OUTFILE       Export the merged data to a CSV file OUTFILE."
	echo "  -h               Print this message and exit."
	echo
	echo "Examples:"
	echo "  Create a BOM list"
	echo "    $(basename $0) -f > bom_list.txt"
	echo
	echo "  Import the BOMs into a new database:"
	echo "    $(basename $0) -i bom_list.txt"
	echo
	echo "  Export the merged BOM to CSV:"
	echo "    $(basename $0) -e full-bom.csv"
	echo
	echo "  Import/export in a single command:"
	echo "    $(basename $0) -i bom_list.txt -e full-bom.csv"
}

if [ $# -lt 1 ]; then
	echo "ERROR: missing arguments"
	usage
	exit 1
fi

DO_IMPORT_CSV=0
DO_EXPORT=0
BOMLIST=
OUTFILE=
while getopts "fi:e:h" opt; do
    case "$opt" in
	f)
		find . -name "*.csv" | grep -i '\/bom\/.*\.csv$' | sort
		exit 0
		;;
	i)
		DO_IMPORT_CSV=1
		BOMLIST=$OPTARG
		;;
	e)
		DO_EXPORT=1
		OUTFILE=$OPTARG
		;;
	h)
		usage
		exit 0
		;;
	?)
		usage
		exit 1
		;;
    esac
done


if [ $DO_IMPORT_CSV -eq 1 ]; then
	if [ ! -f $BOMLIST ]; then
		echo "ERROR: BOM list not found: $BOMLIST"
		exit 1
	fi
	# read the CSV file names from BOMLIST
	arr_files=()
	while read f; do
		if [ -f $f ]; then
			arr_files+=( "$f" )
		else
			echo "ERROR: file listed in $BOMLIST does not exist: $f."
			exit 1
		fi
	done < $BOMLIST

	# create the database
	echo -e "-- Before importing, replace \"\" with 0 in columns sourced and placed\n" > $SQL_SCRIPT
	SQL_SELECT_ALL=
	for i in $(seq ${#arr_files[@]})
	do
		if [ $i -gt 1 ]; then echo >> $SQL_SCRIPT; fi
		cat $SQL_CREATE_TABLE | sed "s/TABLE_NAME/pcbbom$i/" >> $SQL_SCRIPT

		if [ $i -gt 1 ]; then SQL_SELECT_ALL+="\n    UNION ALL\n"; fi
		SQL_SELECT_ALL+="    SELECT * FROM pcbbom$i"
	done
	echo >> $SQL_SCRIPT
	cat $SQL_CREATE_VIEW | sed "s/UNION_SELECT_FROM_ALL_TABLES/$SQL_SELECT_ALL/" >> $SQL_SCRIPT
	rm -f $DBNAME
	sqlite3 $DBNAME < $SQL_SCRIPT

	# import the BOMs into the database
	idx=1
	for f in "${arr_files[@]}"
	do
		# sed, to pass column check:
		# 1. replace "" with 0 in column "placed" (1st occurence)
		# 2. replace "" with 0 in column "sourced" (1st occurence, once "placed" is processed)
		# 3. delete text between (), sometimes found in mate references
		# make a backup
		cp $f $f.tmp
		sed -E -e 's/""/0/1' -e 's/""/0/1' -e 's/\([a-zA-Z0-9_ -]+\)//g' $f > $f.tmp
		TABLE=pcbbom$idx
		echo "$(date -Iseconds) Importing $f into table $TABLE..." | tee -a $LOGFILE
		sqlite3 $DBNAME ".mode csv" ".import -skip 1 $f.tmp $TABLE"
		# remove the hyphen in Farnell part numbers
		sqlite3 $DBNAME \
			"UPDATE $TABLE SET vendor_part_number = replace(vendor_part_number, '-', '') WHERE vendor = 'Farnell'"
		idx=$((idx + 1))
	done
fi

if [ $DO_EXPORT -eq 1 ]; then
	if [ ! -f $DBNAME ]; then
		echo "ERROR: database not found: $DBNAME"
		exit 1
	fi
	sqlite3 $DBNAME ".mode csv" "SELECT * FROM pcb_all;" > $OUTFILE
fi
