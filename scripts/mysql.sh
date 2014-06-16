#!/bin/bash
# this file will load all migrations into the database up to a certain point
# The script is expecting the filename to be in the format:
#   XY_databasename_description.sql
# where:
#   - XY is the order to use to load the migration
#   - databasename is the name of the database to create and use [A-Za-z0-9-]
#   - description is a generic short dash-separated description [A-Za-z0-9-]
# the script is also expecting to have at least a 00_databasename_description.sql file
# that it can use to extract the name of the database from.
#
# - author: Matteo Pescarin <matteo.pescarin[AT]steellondon.com>
#
#
# This code is provided 'as-is'
# and released under the GPLv2

# defaults
DEFAULT_PROJECT_ROOT="/vagrant/"
DEFAULT_DB_SNAPSHOT_DIR="${DEFAULT_PROJECT_ROOT}_database/"
MYSQL_ROOT_USER='root'
MYSQL_ROOT_PASS='password'

# application variables
#DB_NAME=""
#DB_SNAPSHOT=""
#PROJECT_ROOT=""

# application related variables
VERSION="0.1"
NO_ARGS=0
E_OPTERROR=85
E_GENERROR=25
OLD_IFS="$IFS"
IFS=','

function usage() {
    echo -e "Syntax: `basename $0` [-h|-v] [-d <DB_NAME>] [-s <DB_SNAPSHOT>] [-p <PROJECT_ROOT>]
\t-h: shows this help
\t-v: be verbose
\t-d <DB_NAME>: Name of the database to create
\t-s <DB_SNAPSHOT>: absolute path to the sql file to be used to fill the database
\t-p <PROJECT_ROOT>: absolute path of the projcet root in the vagrant VM
\n"
}

function version() {
    echo -e "`basename $0` - Mysql Provisionin Script - version $VERSION\n"
}

function error() {
    version
    echo -e "Error: $1\n"
    usage
}

function quit {
    IFS=$OLD_IFS
    exit $1
}

function create_db() {
    [[ -n $BE_VERBOSE ]] && echo ">> Creating the database $1 and the user $1 with no password"
    mysql -u'${MYSQL_ROOT_USER}' -p'${MYSQL_ROOT_PASS}' <<<EOF
CREATE DATABASE $1 CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER "$1"@'%' IDENTIFIED BY PASSWORD '';
GRANT ALL ON $1.* TO "$1"@'%';
EOF
}

function load_sql() {
    [[ -n $BE_VERBOSE ]] && echo ">> Loading $1 in the $DB_NAME db"
    mysql -u'${MYSQL_ROOT_USER}' -p'${MYSQL_ROOT_PASS}' $DB_NAME < $1
}

# no problems if there are no arguments passed, we'll use the default arguments
#if [ $# -eq "$NO_ARGS" ]; then
#    version
#    usage
#    quit $E_OPTERROR
#fi

# The expected flags are
#  h v r
while getopts ":hvd:s:p:" Option
do
    case $Option in
        h ) version
            usage
            quit 0
            ;;
        v ) BE_VERBOSE=true
            ;;
        d ) DB_NAME=$OPTARG
			;;
        s ) [ ! -e $OPTARG ] && error "'$OPTARG' not accessible" && quit $E_OPTERROR
            DB_SNAPSHOT=$OPTARG
            ;;
        p ) [ ! -e $OPTARG ] && error "'$OPTARG' not accessible" && quit $E_OPTERROR
            PROJECT_ROOT=$OPTARG
            ;;
    esac
done

# Decrements the argument pointer so it points to next argument.
# $1 now references the first non-option item supplied on the command-line
# if one exists.
shift $(($OPTIND - 1))

# initialise the missing variables
if [[ ! -n $PROJECT_ROOT ]]
then
    PROJECT_ROOT=${DEFAULT_PROJECT_ROOT}
fi

# DEPRECATED - retro-compatibility stuff
# DB_SNAPSHOT has not been passed
if [[ ! -n $DB_SNAPSHOT ]]
then
    # let's look in DEFAULT_DB_SNAPSHOT_DIR
    if [[ -e $DEFAULT_DB_SNAPSHOT_DIR ]]
    then
        # if there's more than one file everything will fail
        for file in ${DEFAULT_DB_SNAPSHOT_DIR}*.sql
        do
            [[ -n $BE_VERBOSE ]] && echo ">> Found snapshot $file"
            DB_SNAPSHOT=$file
            DB_NAME=`basename $file .sql`
        done
    fi
elif [[ ! -n $DB_SNAPSHOT ]] && [[ -n $DB_NAME ]]
then
    echo ">> no snapshot defined, db ${DB_NAME} creation only."
    # no snapshot, but we have a db name, create only
    CREATE_DB_ONLY=true
elif [[ -n $DB_SNAPSHOT ]] && [[ ! -n $DB_NAME ]]
then
    echo ">> snapshot defined, no db defined. Guessing."
    DB_NAME=`basename $DB_SNAPSHOT .sql`
fi

[[ -n $BE_VERBOSE ]] && echo ">> PROJECT_ROOT: ${PROJECT_ROOT}"
[[ -n $BE_VERBOSE ]] && echo ">> DB_NAME     : ${DB_NAME}"
[[ -n $BE_VERBOSE ]] && echo ">> DB_SNAPSHOT : ${DB_SNAPSHOT}"

# no snapshot no party
if [[ ! -n ${DB_NAME} ]] && [[ ! -n ${DB_SNAPSHOT} ]]
then
    [[ -n $BE_VERBOSE ]] && echo ">> Snapshot not found. Exiting."
    exit 0
fi


[[ -n $BE_VERBOSE ]] && echo ">> Creating db ${DB_NAME}"
create_db $DB_NAME
if [[ -n $CREATE_DB_ONLY ]]
then
    [[ -n $BE_VERBOSE ]] && echo ">> Filling db with ${DB_SNAPSHOT}"
    query_db $DB_SNAPSHOT
fi

exit 0
