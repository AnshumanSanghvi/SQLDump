#/bin/bash

# Script to dump db using mysqldump command with support for excluding explicitly mentioned tables, and excluding tables matching name patterns.
# This script generates $DUMP_FILE, and log errors to $ERROR_LOG
# usage: `nohup sh mysqldumpscript.sh &;`
# view diagnostics / info in the files nohup.out and ERROR_LOG
# author: anshumansanghvi

set -eE

# enter user name, password, database name and host
user="root"
pass="" # enter password here to avoid being prompted
DB=""
HOST="localhost"
ENV="LOCAL"
curr_date=$(date '+%Y%m%d%H%M%S');
DUMP_FILE=$DB"_"$ENV"_"$curr_date"_dbdump.sql"
ERROR_LOG=$DUMP_FILE"_error.log"

# enter patterns whose matching table names should be excluded
# usage: begins-with: name%, ends-with: %name
PATTERNS_ARRAY=(
startswith1%
startswith2%
%endswith1
)

IGNORED_PATTERNS_STRING=''

for PATTERN in "${PATTERNS_ARRAY[@]}"
do :
# mysql params:
#-u user name
#-p password
#-D database name
#-B Batch mode: avoid using table formatting (so that I can append to string) and escape of special characters.
#-s Silent mode. skip column names.
#-e execute sql statement
  IGNORED_PATTERNS_STRING+=" "$(mysql -u $user -p$pass -D $DB -Bs -A -e "SHOW TABLES LIKE '${PATTERN}';")
done

EXCLUDED_TABLES_STRING="${IGNORED_PATTERNS_STRING}"

# ------------------------------

# enter explicit table names that should be excluded
TABLE_NAMES_ARRAY=(
table1
table2
table3
table4
)

IGNORED_TABLES_STRING=''

for TABLE in "${TABLE_NAMES_ARRAY[@]}"
do :
   IGNORED_TABLES_STRING+=" ${TABLE}"
done

EXCLUDED_TABLES_STRING="$EXCLUDED_TABLES_STRING"" ""${IGNORED_TABLES_STRING}"

# ------------------------------

# uncomment to print out list of all excluded tables
echo $EXCLUDED_TABLES_STRING;

# ------------------------------

IGNORE_TABLE_PARAM=''

EXCLUDED_TABLES_ARR=(`echo $EXCLUDED_TABLES_STRING | cut -d " "  --output-delimiter=" " -f 1-`)

for EXCLUDED_TABLE in "${EXCLUDED_TABLES_ARR[@]}"
do :
   IGNORE_TABLE_PARAM+=" --ignore-table=${DB}.${EXCLUDED_TABLE}"
done

# ------------------------------

# mysqldump params
# --host: host name of db server
# --user: user name of db
# --password: password for user
# --single-transaction: sets the transaction isolation mode to REPEATABLE READ and sends a START TRANSACTION SQL statement to the server before dumping data. It dumps the consistent state of the database at the time when START TRANSACTION was issued without blocking any applications. The --single-transaction option and the --lock-tables option are mutually exclusive because LOCK TABLES causes any pending transactions to be committed implicitly.
# --no-data: do not dump table contents
# --routines: dump stored procedures and functions
# --add-drop-database: Add DROP DATABASE statement before each CREATE DATABASE statement
# --add-drop-table: Add DROP TABLE statement before each CREATE TABLE statement
# --no-create-info: Do not write CREATE TABLE statements that re-create each dumped table
# --skip-triggers: Do not dump triggers

# note:
# The user executing mysqldump must have the following privileges: SELECT privilege for dumped tables, SHOW VIEW for dumped views, TRIGGER for dumped triggers, LOCK TABLES if the --single-transaction option is not used, and PROCESS if the --no-tablespaces option is not used.

echo "Dumping Schema to $DUMP_FILE"
mysqldump --host=${HOST} --user=${user} --password=${pass} --single-transaction --no-data --routines --add-drop-database --add-drop-table ${IGNORE_TABLE_PARAM} ${DB} 1> ${DUMP_FILE} 2>> ${ERROR_LOG}

echo "Dumping Data to $DUMP_FILE"
mysqldump --host=${HOST} --user=${user} --password=${pass} --no-create-info --skip-triggers ${IGNORE_TABLE_PARAM} ${DB} 1>> ${DUMP_FILE} 2>> ${ERROR_LOG}

echo "Completed"

# ------------------------------

# When creating db from dump, install pv for tracking progress.
# Debian: apt-get install pv / RedHat: yum install pv / Mac : brew install pv
# usage: pv $DUMP_FILE | mysql -u $user -p$pass -D $DB
