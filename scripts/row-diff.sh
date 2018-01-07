#!/bin/bash

set -euf -o pipefail

# Script to visualize differences in two file more clearly
# 
# Takes side-by-side diff output and runs it through AWK script.
# Rows which contain differences or are new or deleted are printed out.
# If a modified row can be split by tabs, each "column" is examined separately.
# Differences are highlited with colors in terminal

# Licensed under MIT License (see LICENSE.md at root)

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-c] [FILE 1] [FILE 2]

Compare FILE 1 to FILE 2 and highlight differences for human readers. 
Use terminal colors if -c option is given.

    -c          use terminal colors
EOF
}

OPTIND=1         # Reset in case getopts has been used previously in the shell.

use_color=0
while getopts c opt; do
	case $opt in
		c)
			use_color=1
			;;
		*)
			show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

# Check that two arguments remain
if [ $# != 2 ] ; then 
	show_help >&2
	exit 1
fi

diff --suppress-common-lines --side-by-side --minimal --width 500 $1 $2 | \
awk -v with_color=$use_color 'BEGIN {
	FS="[|<>]";
	# Colors
	if (with_color == 1) {
		C_OLD="\033[31m"
		C_NEW="\033[32m"
		C_CLEAR="\033[0m"
	}
}
{
    if ($0 ~ "<") {
        row_state = "deleted";
    } else if ($0 ~ ">") {
        row_state = "new";
    } else if ($0 ~ "[|]") {
        row_state = "modified";
    } else {
		row_state = "same"
	}
    
    if (row_state == "modified") {
        printf("% 4i: M : ", NR)
		part_1_nf = split(trim($1), part_1_array, "\t")
		part_2_nf = split(trim($2), part_2_array, "\t")
		if (part_1_nf != part_2_nf) {
			# Dont compare columns
			printf(C_OLD"(%s)"C_CLEAR" -> "C_NEW"(%s)"C_CLEAR"\n", trim($1), trim($2))
		} else {
			for (f = 1 ; f <= part_1_nf ; f++) {
				printf("%s", chk_field(part_1_array[f], part_2_array[f]))
				if (f + 1 <= part_1_nf) {
					printf("%s", "\t");
				}
			}
			printf("%s", "\n");
        }
    } else if (row_state == "new") {
        printf("% 4i: + : ", NR)
		printf(C_NEW"%s\n"C_CLEAR, trim($2));
    } else if (row_state == "deleted") {
        printf("% 4i: - : ", NR)
		printf(C_OLD"%s\n"C_CLEAR, trim($1));
    }
}
function chk_field(field_a, field_b) {
    if (field_a == field_b) {
        return sprintf("%s", field_a)
    } else {
        return sprintf("("C_OLD"%s"C_CLEAR" -> "C_NEW"%s"C_CLEAR")", field_a, field_b)
    }
}
function trim(str) {
	gsub(/^[ \t]+|[ \t]+$/, "", str);
	return str
}
'
