#!/usr/bin/bash

# Import BOM CSV files into a SQLite database, merge them, export the data.

DBNAME=mrgbom.sqlite3
SQL_SCRIPT=${0%$(basename $0)}/mkdb.sql

function usage()
{
	echo "Usage: $(basename $0) [OPTIONS]"
	echo "Import BOMs from several PCBs into an SQLite database to merge them: sum the"
	echo "quantities, insert mate parts as new entries. The result can be exported to"
	echo "a CSV file."
	echo
	echo "Options:"
	echo "  -c               Create the database $DBNAME. Overwrite the existing one."
	echo "  -f               Try to find BOMs in subdirectories 'bom/' (case insensitive),"
	echo "                   print to stdout and exit."
	echo "  -i BOMLIST       Import the CSV files into the database listed in BOMLIST,"
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
	echo "  Create the databse and import the BOMs:"
	echo "    $(basename $0) -c"
	echo "    $(basename $0) -i bom_list.txt"
	echo
	echo "  Export the merged BOM to CSV:"
	echo "    $(basename $0) -e full-bom.csv"
}

if [ $# -lt 1 ]; then
	echo "ERROR: missing arguments"
	usage
	exit 1
fi

DO_CREATE_DB=0
DO_IMPORT_CSV=0
DO_EXPORT=0
BOMLIST=
OUTFILE=
while getopts "cfi:e:h" opt; do
    case "$opt" in
	c)
		DO_CREATE_DB=1
		;;
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

if [ $DO_CREATE_DB -eq 1 ]; then
	choice=y
	read -p "WARNING: $DBNAME will be deleted. Continue (Y/n)? " choice
	case "$choice" in
	y|Y )
		;;
	n|N )
		exit 0
		;;
	* )
		if [ "$choice" != "" ]; then
			echo "Invalid: '$choice'"; exit 1
		fi
		;;
	esac
	rm -f $DBNAME
	sqlite3 $DBNAME < $SQL_SCRIPT
fi

if [ $DO_IMPORT_CSV -eq 1 ]; then
	if [ ! -f $BOMLIST ]; then
		echo "ERROR: BOM list not found: $BOMLIST"
		exit 1
	fi
	# read the CSV file names from
	arr_files=()
	while read f; do
		if [ -f $f ]; then
			arr_files+=( "$f" )
		else
			echo "ERROR: file listed in $BOMLIST does not exist: $f."
			exit 1
		fi
	done < $BOMLIST

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
		echo "Importing $f into table $TABLE..."
		sqlite3 $DBNAME ".mode csv" ".import -skip 1 $f.tmp $TABLE"
		# remove the hyphen in Farnell part numbers
		sqlite3 $DBNAME \
			"UPDATE $TABLE SET vendor_part_number = replace(vendor_part_number, '-', '') WHERE vendor = 'Farnell'"
		idx=$((idx + 1))
	done
fi

if [ $DO_EXPORT -eq 1 ]; then
	sqlite3 $DBNAME ".mode csv" "SELECT * FROM pcb_all;" > $OUTFILE
fi
