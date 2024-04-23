#!/usr/bin/env bash
# pre_assist.sh
# file distributed with  Mariadb Start Replica Assistant
# By Edward Stoever for MariaDB Support

TMPDIR="/tmp"
TOOL="start_replica_assistant"
CONFIG_FILE="$SCRIPT_DIR/assistant.cnf"
PRE_LOOP=true
REQUEST_RESPONSE=true
VAR_REPORT=()
LOG_FILE=${TMPDIR}/start_replica_assistant_$(date +'%m%d_%H%M%S').log
SECONDS=0 
MLLS=50 # milliseconds pause between each skip, if lower than 300, script may stop prematurely
MLTP=1  # how many binlog events to skip from the primary at a time, default 1.
SKIPPED_EVENTS=0
unset DEFAULT_CONNECTION_NAME


function ts() {
   TS=$(date +%F-%T | tr ':-' '_')
   echo "$TS $*"
}

function die() {
   ts "$*" >&2
   exit 1
}

if [ ! $SCRIPT_VERSION ]; then  die "Do not run this script directly. Read the file README.md for help."; fi

function display_help_message() {
printf "This script can be run without options. Not indicating an option value will use the default.
  --skip_multiplier=100 # How many binlog events to skip from the primary at a time, default 1.
                        # Skipping multiples will speed up the process of finding the first transaction 
                        # that does not fail. Skipping multiples can also lead to skipping transactions 
                        # that would otherwise succeed. For more details, review the file README.md.
  --milliseconds=75     # Pause between each error skipped in miliseconds. Default 50.
  --nocolor             # Do not display with color letters
  --nolog               # Do not write a logfile into directory ${TMPDIR}
  --bypass_priv_check   # Bypass the check that the database user has sufficient privileges.
  --test                # Test connect to database and display script version.
  --version             # Test connect to database and display script version.
  --help                # Display the help menu

Read the file README.md for more information.\n"
if [ $INVALID_INPUT ]; then die "Invalid option: $INVALID_INPUT"; fi
}

function display_title(){
  local BLANK='  │                                                         │'
  printf "  ┌─────────────────────────────────────────────────────────┐\n"
  printf "$BLANK\n"
  printf "  │             MARIADB START REPLICA ASSISTANT             │\n"
  printf '%-62s' "  │                      Version $SCRIPT_VERSION"; printf "│\n"
  printf "$BLANK\n"
  printf "  │      Script by Edward Stoever for MariaDB Support       │\n"
  printf "$BLANK\n"
  printf "  └─────────────────────────────────────────────────────────┘\n"

}

function start_message() {
  if [ ! $PRE_LOOP ]; then return; fi
  $CMD_MARIADB $CLOPTS -s -e "select now();" 1>/dev/null 2>/dev/null && CAN_CONNECT=true || unset CAN_CONNECT
  if [ $CAN_CONNECT ]; then
    TEMP_COLOR=lgreen; print_color "Can connect to database.\n"; unset TEMP_COLOR; unset PRE_LOOP;
  else
    TEMP_COLOR=lred;   print_color "Cannot connect to database.\n"; unset TEMP_COLOR;
  fi

  if [ ! $CAN_CONNECT ]; then 
    TEMP_COLOR=lred; print_color "Failing command: ";unset TEMP_COLOR; 
    TEMP_COLOR=lyellow; print_color "$CMD_MARIADB $CLOPTS\n";unset TEMP_COLOR; 
    local ERRTEXT=$($CMD_MARIADB $CLOPTS -e "select now();" 2>&1); TEMP_COLOR=lcyan; print_color "$ERRTEXT\n";unset TEMP_COLOR;
  fi

  if [ $HELP ]; then display_help_message; exit 0; fi
  if [ $DISPLAY_VERSION ]; then exit 0; fi
  if [ ! $CAN_CONNECT ]; then  die "Database connection failed. Read the file README.md. Edit the file simulator.cnf."; fi
}

function print_color () {
  if [ -z "$COLOR" ] && [ -z "$TEMP_COLOR" ]; then printf "$1"; return; fi
    if [ $NOCOLOR ]; then printf "$1"; return; fi
  case "$COLOR" in
    default) i="0;36" ;;
    red)  i="0;31" ;;
    blue) i="0;34" ;;
    green) i="0;32" ;;
    yellow) i="0;33" ;;
    magenta) i="0;35" ;;
    cyan) i="0;36" ;;
    lred) i="1;31" ;;
    lblue) i="1;34" ;;
    lgreen) i="1;32" ;;
    lyellow) i="1;33" ;;
    lmagenta) i="1;35" ;;
    lcyan) i="1;36" ;;
    *) i="0" ;;
  esac
if [ $TEMP_COLOR ]; then
  case "$TEMP_COLOR" in
    default) i="0;36" ;;
    red)  i="0;31" ;;
    blue) i="0;34" ;;
    green) i="0;32" ;;
    yellow) i="0;33" ;;
    magenta) i="0;35" ;;
    cyan) i="0;36" ;;
    lred) i="1;31" ;;
    lblue) i="1;34" ;;
    lgreen) i="1;32" ;;
    lyellow) i="1;33" ;;
    lmagenta) i="1;35" ;;
    lcyan) i="1;36" ;;
    *) i="0" ;;
  esac
fi
  printf "\033[${i}m${1}\033[0m"

}

function _which() {
   if [ -x /usr/bin/which ]; then
      /usr/bin/which "$1" 2>/dev/null | awk '{print $1}'
   elif which which 1>/dev/null 2>&1; then
      which "$1" 2>/dev/null | awk '{print $1}'
   else
      echo "$1"
   fi
}

function type_of_transaction(){
 local STR=$(printf "$1" | awk '{print toupper($0)}' | sed 's/CREATE USER/CREATE_USER/g' | sed 's/ALTER USER/ALTER_USER/g' | sed 's/DROP USER/DROP_USER/g' | sed 's/BINLOG GTID/BINLOG_GTID/g' | sed "s/['\"]//g" | sed 's/ /\n/g')

 local SUBS=('WRITE_ROWS_V1'
        'UPDATE_ROWS_V1'
        'DELETE_ROWS_V1'
        'WRITE_ROWS_COMPRESSED_V1'
        'UPDATE_ROWS_COMPRESSED_V1'
        'DELETE_ROWS_COMPRESSED_V1'
        'CREATE_USER'
        'DROP_USER'
        'ALTER_USER'
        'GRANT'
        'BINLOG_GTID'
        'INSERT'
        'UPDATE'
        'DELETE'
        'CREATE');
        
# first 30 words is enough:
for (( ii=1; ii<=30; ii++ )) 
do 
  local WRD=$(printf "$STR" | awk "NR==$ii"); 
  if [ "$WRD" == "" ]; then break; fi
  for SUB in "${SUBS[@]}"
  do
     if [ "$SUB" == "$WRD" ]; then
      echo "$WRD";  return
     fi
   done;
done;
echo "OTHER"; 
}

function skip_everything(){
  SKIP_EVERYTHING=true;
}

function skip_list(){
 SKIP_LIST+=("$ERR_CODE")
}

function check_request_response(){ 
  REQUEST_RESPONSE=true
  if [ $SKIP_EVERYTHING ]; then unset REQUEST_RESPONSE; RESPONSE="c"; return; fi
  for ii in "${SKIP_LIST[@]}"; 
  do
   if [[ "$ii" == "$ERR_CODE" ]]; then unset REQUEST_RESPONSE; RESPONSE="c"; fi
  done
}

function display_error_skip_message(){
local MNG="Unexpected error." #DEFAULT VALUE
local FACTOR="Unknown."       #DEFAULT VALUE
  if [ "$SQL_ERRNO" != "0" ]; then
   if [ "$SQL_ERRNO" == "1062" ] && [ "$TX_TYPE" == "WRITE_ROWS_V1" ]; then 
     local MNG="Row with specific primary/unique key inserted on master already exists on slave. Perhaps inserted on slave first."; 
     local FACTOR="Low probability of divergence."
   fi
   if [ "$SQL_ERRNO" == "1032" ]; then
     if [ "$TX_TYPE" == "DELETE_ROWS_V1" ]; then
      local MNG="Row deleted on master does not exists on slave. Perhaps deleted on slave first."; 
      local FACTOR="Low probability of divergence."
     fi
     if [ "$TX_TYPE" == "UPDATE_ROWS_V1" ]; then 
      local MNG="Row updated on master does not exists on slave."; 
      local FACTOR="Divergence exists in slave."
     fi
   fi
   if [ "$SQL_ERRNO" == "1146" ]; then 
     local MNG="Row event on master but table does not exists on slave."; 
     local FACTOR="Divergence exists in slave."
   fi
   if [ "$SQL_ERRNO" == "1396" ]; then 
     if [ "$TX_TYPE" == "CREATE_USER" ]; then
      local MNG="CREATE USER failed on slave. Perhaps account already exists on slave."; 
      local FACTOR="Password and privileges could be different on slave."
     fi
     if [ "$TX_TYPE" == "ALTER_USER" ]; then
      local MNG="ALTER USER failed on slave. Account does not exist on slave."; 
      local FACTOR="Can be fixed by creating user on slave."
     fi
     if [ "$TX_TYPE" == "DROP_USER" ]; then
      local MNG="DROP USER failed on slave. Account does not exist on slave."; 
      local FACTOR="Low probability of divergence."
     fi
   fi
   if [ "$SQL_ERRNO" == "1054" ]; then 
     local MNG="A Column is unknown on the slave. Table has different definition on slave."; 
     local FACTOR="Divergence exists in slave regardless of skipping error."
   fi
   printf "       ERROR TYPE: "; TEMP_COLOR=lcyan;   print_color "SQL\n"; unset TEMP_COLOR;
   printf "       ERROR CODE: "; TEMP_COLOR=lcyan;   print_color "$SQL_ERRNO"; if [ "$TX_TYPE" ]; then print_color " (${TX_TYPE})"; fi;  unset TEMP_COLOR; printf "\n"
   printf "          MEANING: "; TEMP_COLOR=lcyan;   print_color "$MNG\n"; unset TEMP_COLOR;
   printf "DIVERGENCE FACTOR: "; TEMP_COLOR=lcyan;   print_color "$FACTOR\n"; unset TEMP_COLOR;
   printf "    ERROR MESSAGE: "; TEMP_COLOR=lcyan;   print_color "$SQL_ERR\n"; unset TEMP_COLOR;
fi
  if [ "$IO_ERRNO" != "0" ]; then
   local FACTOR="Low probability of divergence."       #DEFAULT VALUE
   printf "       ERROR TYPE: "; TEMP_COLOR=lcyan;   print_color "IO\n"; unset TEMP_COLOR;
   printf "       ERROR CODE: "; TEMP_COLOR=lcyan;   print_color "$IO_ERRNO"; if [ "$TX_TYPE" ]; then print_color " (${TX_TYPE})"; fi;  unset TEMP_COLOR; printf "\n"
   printf "DIVERGENCE FACTOR: "; TEMP_COLOR=lcyan;   print_color "$FACTOR\n"; unset TEMP_COLOR;
   printf "    ERROR MESSAGE: "; TEMP_COLOR=lcyan;   print_color "$IO_ERR\n"; unset TEMP_COLOR;
  fi
if [ "$IO_ERRNO" != "0" ] || [ "$SQL_ERRNO" != "0" ]; then 
  if [ "$REQUEST_RESPONSE" ]; then
     TEMP_COLOR=lgreen; print_color "\n------------- CHOOSE AN OPTION -------------\n"; unset TEMP_COLOR;
     printf "Press "; TEMP_COLOR=lred; print_color "c";  printf " to "; print_color "continue"; printf ". Slave will skip only this occurrence.\n"; unset TEMP_COLOR;
     printf "Press "; TEMP_COLOR=lred; print_color "a";  printf " to "; print_color "auto-skip"; printf ". Slave will skip all occurrences of ${SQL_ERRNO} (${TX_TYPE}).\n"; unset TEMP_COLOR;
     printf "Press "; TEMP_COLOR=lred; print_color "e"; printf " to "; print_color "everything"; printf ". Slave will skip every error possible.\n"; unset TEMP_COLOR;
  fi
fi
}

function skip_this_err(){
SKIP_SQL="set global sql_slave_skip_counter=${MLTP}; start slave; do sleep(${MLLS}/1000);" 
if [ $DEFAULT_CONNECTION_NAME ]; then
  SKIP_SQL="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${SKIP_SQL}"
fi
if [ "$IO_ERRNO" == "0" ]; then
  case "$SQL_ERRNO" in
    "1950")
      local TURN_OFF_STRICT_MODE_SQL="STOP SLAVE; set global gtid_strict_mode=OFF; do sleep(0.1); START SLAVE; do sleep(1);"
      if [ $DEFAULT_CONNECTION_NAME ]; then
        local TURN_OFF_STRICT_MODE_SQL="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${TURN_OFF_STRICT_MODE_SQL}"
      fi
      TEMP_COLOR=lred;   print_color "Setting global gtid_strict_mode = OFF\n"; unset TEMP_COLOR;
      $CMD_MARIADB $CLOPTS -ABNe "$TURN_OFF_STRICT_MODE_SQL"
      VAR_REPORT+=("$ERR_CODE")
      logit
      GTID_STRICT_MODE_WAS_CHANGED=true
;;
    *)
    $CMD_MARIADB $CLOPTS -ABNe "$SKIP_SQL"
    VAR_REPORT+=("$ERR_CODE")
    SKIPPED_EVENTS=$((SKIPPED_EVENTS + 1))
    logit
   TEMP_COLOR=lgreen; print_color "\n============================================\n"; unset TEMP_COLOR;
;;
  esac
else
  case "$IO_ERRNO" in
    "1236")
    local SWITCH_MASTER_USE_GTID_TO_SLAVE_POS="STOP SLAVE; CHANGE MASTER TO MASTER_USE_GTID = slave_pos; START SLAVE; do sleep(1);"
    
  if [ $DEFAULT_CONNECTION_NAME ]; then
    SWITCH_MASTER_USE_GTID_TO_SLAVE_POS="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${SWITCH_MASTER_USE_GTID_TO_SLAVE_POS}"
  fi
    
    if [ "$MASTER_USE_GTID_AT_SCRIPT_START" == "Current_Pos" ] && [ $(echo $IO_ERR| grep -i "connecting slave requested to start from GTID"| awk '{print $1}') ]; then
      TEMP_COLOR=lred;   print_color "Switching to MASTER_USE_GTID = slave_pos\n"; unset TEMP_COLOR;
      $CMD_MARIADB $CLOPTS -ABNe "${SWITCH_MASTER_USE_GTID_TO_SLAVE_POS}"
      VAR_REPORT+=("${IO_ERRNO}_${TX_TYPE}")
      MASTER_USE_GTID_WAS_CHANGED=true
      logit
      TEMP_COLOR=lgreen; print_color "\n============================================\n"; unset TEMP_COLOR;
    else
      echo "This IO error is not handled by this script";
      echo "$MASTER_USE_GTID_AT_SCRIPT_START"
      echo OK
      exit 0
    fi
;;
    *)
    echo "This IO error is not handled by this script";
    exit 0
;;
  esac

fi
}

function is_replica() {
 if [ "$SLAVE_STATUS" == "" ]; then
   HN_SQL="select VARIABLE_VALUE from information_schema.GLOBAL_VARIABLES where VARIABLE_NAME='HOSTNAME';"
   HN=$($CMD_MARIADB $CLOPTS -ABNe "$HN_SQL")
   die "The mariadb instance running on host \"$HN\" does not appear to be a replica."; 
 fi
}


function no_errors() {
  if [ "${IO_ERRNO}" == "0" ] && [ "${SQL_ERRNO}" == "0" ]; then
    TEMP_COLOR=lgreen; print_color "Replication is currently working without error.\n"; unset TEMP_COLOR; 
    exit 0    
  fi
}

function gtid_strict_mode_at_script_start() {
  local GTID_STRICT_SQL="select VARIABLE_VALUE from information_schema.GLOBAL_VARIABLES where VARIABLE_NAME='GTID_STRICT_MODE';"
  GTID_STRICT_MODE_AT_SCRIPT_START=$($CMD_MARIADB $CLOPTS -ABNe "$GTID_STRICT_SQL")
}

# function master_use_gtid_at_script_start() {
# local STATUS_SQL="SHOW SLAVE STATUS\G"
#  if [ $DEFAULT_CONNECTION_NAME ]; then
#    local STATUS_SQL="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${STATUS_SQL}"
#  fi
#  local SLAVE_STATUS=$($CMD_MARIADB $CLOPTS -Ae "$STATUS_SQL" | sed  's/\%/\%\%/g') # -- printf will gag on one %  
#  MASTER_USE_GTID_AT_SCRIPT_START=$(printf  "$SLAVE_STATUS" | grep -i Using_Gtid | cut -d':' -f2- | awk '{$1=$1};1')
#}

function set_sql_slave_skip_counter_to_zero(){
  if [ "$MLTP" == "1" ]; then return; fi
  local SQL_SLAVE_SKIP_COUNTER="stop slave; set global sql_slave_skip_counter=0; start slave;"; 
  local MSG="Setting sql_slave_skip_counter = 0"
  if [ $NOLOG ]; then
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR;
  else
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR; echo "${MSG}" >> ${LOG_FILE}; 
  fi
  $CMD_MARIADB $CLOPTS -ABNe "$SQL_SLAVE_SKIP_COUNTER"
}

function return_gtid_strict_mode_to_start_value(){
  if [ ! $GTID_STRICT_MODE_AT_SCRIPT_START ]; then return; fi
  if [ ! $GTID_STRICT_MODE_WAS_CHANGED ]; then return; fi
  local MSG="Setting global gtid_strict_mode = ${GTID_STRICT_MODE_AT_SCRIPT_START}\n"
  local RETURN_STRICT_MODE_SQL="set global gtid_strict_mode=${GTID_STRICT_MODE_AT_SCRIPT_START};"
  if [ $NOLOG ]; then
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR;
  else
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR; printf "${MSG}" >> ${LOG_FILE}; 
  fi
  $CMD_MARIADB $CLOPTS -ABNe "$RETURN_STRICT_MODE_SQL"
}

function return_master_use_gtid_to_start_value(){
  if [ ! $MASTER_USE_GTID_AT_SCRIPT_START ]; then return; fi
  if [ ! $MASTER_USE_GTID_WAS_CHANGED ]; then return; fi
  local RETURN_GTID_MASTER_USE_GTID_SQL="STOP SLAVE; CHANGE MASTER TO MASTER_USE_GTID = ${MASTER_USE_GTID_AT_SCRIPT_START}; START SLAVE;"
  local MSG="Switching to MASTER_USE_GTID = ${MASTER_USE_GTID_AT_SCRIPT_START}\n"
  if [ $NOLOG ]; then
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR;
  else
    TEMP_COLOR=lred; print_color "${MSG}"; unset TEMP_COLOR; printf "${MSG}" >> ${LOG_FILE}; 
  fi
  $CMD_MARIADB $CLOPTS -ABNe "$RETURN_GTID_MASTER_USE_GTID_SQL"
}

function is_there_one_named_connection(){
 local ALL_STATUS_SQL="SHOW ALL SLAVES STATUS\G"
 ALL_STATUS=$($CMD_MARIADB $CLOPTS -Ae "$ALL_STATUS_SQL" | sed  's/\%/\%\%/g') # -- printf will gag on one % 
 CONNECTION_NAMES_COUNT=$(printf  "$ALL_STATUS" | grep -i Connection_name  | wc -l)
if [ $CONN_NAME ]; then
  CONN_NAME_IS_VALID=$(printf  "$ALL_STATUS" | grep -i Connection_name  | grep $CONN_NAME | wc -l)
fi
 if [ "$CONNECTION_NAMES_COUNT" == "0" ]; then
   TEMP_COLOR=lred; print_color "\nThere are no slaves.\n\n"; unset TEMP_COLOR;
   exit 0
 fi
 if [ "$CONNECTION_NAMES_COUNT" == "1" ]; then
   DEFAULT_CONNECTION_NAME=$(printf  "$ALL_STATUS" | grep -i Connection_name | cut -d':' -f2- | awk '{$1=$1};1')
 fi
 if [ "$CONNECTION_NAMES_COUNT" == "1" ] && [ ! "$DEFAULT_CONNECTION_NAME" ]; then
   # THERE IS ONE CONNECTION, NOT NAMED
   return;
 fi
 if [ ! "$DEFAULT_CONNECTION_NAME" ]; then
# DEFAULT_CONNECTION_NAME which comes from system overrides one provided by user.
   if [ $CONN_NAME ]; then
     if [ "$CONN_NAME_IS_VALID" == "1" ]; then
       DEFAULT_CONNECTION_NAME="$CONN_NAME"
       TEMP_COLOR=lmagenta; print_color "\nUsing slave connection name ${DEFAULT_CONNECTION_NAME} as default.\n\n"; unset TEMP_COLOR;
     else
       TEMP_COLOR=lred; print_color "\n--conn_name=${CONN_NAME} is not a valid connection name.\n\n"; unset TEMP_COLOR;
     fi
     return
   fi
    TEMP_COLOR=lred; print_color "\nThere are ${CONNECTION_NAMES_COUNT} named replication connections. You must indicate one.\n\n"; unset TEMP_COLOR;
    exit 0
 fi
# IF YOU HAVE GOTTEN THIS FAR, THERE IS ONE CONNECTION NAME, AND IT IS THE DEFAULT
TEMP_COLOR=lmagenta; print_color "\nUsing slave connection name ${DEFAULT_CONNECTION_NAME} as default.\n\n"; unset TEMP_COLOR;
}

function set_slave_status_vars() {
  STATUS_SQL="SHOW SLAVE STATUS\G"
  if [ $DEFAULT_CONNECTION_NAME ]; then
    STATUS_SQL="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${STATUS_SQL}"
  fi
  SLAVE_POS_SQL="select VARIABLE_VALUE from information_schema.GLOBAL_VARIABLES where variable_name='GTID_SLAVE_POS';"
  GTID_STRICT_SQL="select VARIABLE_VALUE from information_schema.GLOBAL_VARIABLES where VARIABLE_NAME='GTID_STRICT_MODE';"
  SLAVE_STATUS=$($CMD_MARIADB $CLOPTS -Ae "$STATUS_SQL" | sed  's/\%/\%\%/g') # -- printf will gag on one %  
  GTID_SLAVE_POS=$($CMD_MARIADB $CLOPTS -ABNe "$SLAVE_POS_SQL")
  CURRENT_GTID_STICT_MODE=$($CMD_MARIADB $CLOPTS -ABNe "$GTID_STRICT_SQL")
   IO_ERRNO=$(printf  "$SLAVE_STATUS" | grep -i Last_IO_Errno  | cut -d':' -f2- | awk '{$1=$1};1')
     IO_ERR=$(printf  "$SLAVE_STATUS" | grep -i Last_IO_Error  | cut -d':' -f2- | awk '{$1=$1};1' | sed  "s/\%/\%\%/g" | sed "s/\`//g")
  SQL_ERRNO=$(printf  "$SLAVE_STATUS" | grep -i Last_SQL_Errno | cut -d':' -f2- | awk '{$1=$1};1')
    SQL_ERR=$(printf  "$SLAVE_STATUS" | grep -i Last_SQL_Error | cut -d':' -f2- | awk '{$1=$1};1' | sed  "s/\%/\%\%/g" | sed "s/\`//g")  # -- printf will gag on one %  
GTID_IO_POS=$(printf  "$SLAVE_STATUS" | grep -i Gtid_IO_Pos    | cut -d':' -f2- | awk '{$1=$1};1')
 USING_GTID=$(printf  "$SLAVE_STATUS" | grep -i Using_Gtid     | cut -d':' -f2- | awk '{$1=$1};1')
    TX_TYPE=$(type_of_transaction "$SQL_ERR")
    MASTER_USE_GTID_AT_SCRIPT_START="$USING_GTID"
   ERR_CODE="${SQL_ERRNO}_${TX_TYPE}"
}

function logit(){
if [ $NOLOG ]; then return; fi
if [ "$SQL_ERRNO" != "0" ]; then
   printf "================== ERROR SKIPPED ==================\n"  >> ${LOG_FILE}
   printf "       ERROR CODE: $SQL_ERRNO (${TX_TYPE})\n" >> ${LOG_FILE}
   printf "          MEANING: $MNG\n">> ${LOG_FILE}
   printf "DIVERGENCE FACTOR: $FACTOR\n">> ${LOG_FILE}
   printf "    ERROR MESSAGE: $SQL_ERR\n">> ${LOG_FILE}
   printf "===================================================\n"  >> ${LOG_FILE}
fi
if [ "$IO_ERRNO" != "0" ]; then
   printf "================== IO ERROR FIXED ==================\n"  >> ${LOG_FILE}
   printf "       ERROR CODE: $IO_ERRNO (${TX_TYPE})\n" >> ${LOG_FILE}
   printf "          MEANING: $MNG\n">> ${LOG_FILE}
   printf "DIVERGENCE FACTOR: $FACTOR\n">> ${LOG_FILE}
   printf "    ERROR MESSAGE: $IO_ERR\n">> ${LOG_FILE}
   printf "====================================================\n"  >> ${LOG_FILE}
fi
}

function display_report(){
 if [ "${#VAR_REPORT[@]}" == "0" ]; then return; fi
if [ $NOLOG ]; then
  printf "\n\n COUNT   SKIPPED ERROR\n------- --------------------------\n"  
 (IFS=$'\n'; sort <<< "${VAR_REPORT[*]}") | uniq -c  
 else
 printf "\n\n COUNT   SKIPPED ERROR\n------- --------------------------\n" | tee -a ${LOG_FILE}
 (IFS=$'\n'; sort <<< "${VAR_REPORT[*]}") | uniq -c | tee -a ${LOG_FILE}
fi
}

final_check_for_slave_error(){
  STATUS_SQL="do sleep(0.5); SHOW SLAVE STATUS\G"
  if [ $DEFAULT_CONNECTION_NAME ]; then
    STATUS_SQL="set default_master_connection='${DEFAULT_CONNECTION_NAME}'; ${STATUS_SQL}"
  fi
  SLAVE_STATUS=$($CMD_MARIADB $CLOPTS -Ae "$STATUS_SQL" | sed  's/\%/\%\%/g') # -- printf will gag on one %  
      IO_ERRNO=$(printf  "$SLAVE_STATUS" | grep -i Last_IO_Errno  | cut -d':' -f2- | awk '{$1=$1};1')
     SQL_ERRNO=$(printf  "$SLAVE_STATUS" | grep -i Last_SQL_Errno | cut -d':' -f2- | awk '{$1=$1};1') 

if [ "$IO_ERRNO" != "0" ] || [ "$SQL_ERRNO" != "0" ]; then
 TEMP_COLOR=lred; print_color "\nThis script exited early. Increase milliseconds to avoid this issue.\n\n"; unset TEMP_COLOR;
fi

}

function check_required_privs() {
local SQL="delimiter //
begin not atomic
set @HAS_SUPER='NONE';
select PRIVILEGE_TYPE into @HAS_SUPER 
from information_schema.USER_PRIVILEGES 
where replace(GRANTEE,'''','')=current_user()
and PRIVILEGE_TYPE='SUPER';

set @MISSING_PRIVS='NONE';
select GROUP_CONCAT(\`PRIVILEGE\` SEPARATOR ', ') into @MISSING_PRIVS from (
select 1 as \`ONE\`, \`PRIVILEGE\` FROM(
WITH REQUIRED_PRIVS as (
select 'REPLICATION SLAVE ADMIN' as PRIVILEGE UNION ALL
select 'SLAVE MONITOR' as PRIVILEGE  )
SELECT A.PRIVILEGE , B.TABLE_CATALOG
from REQUIRED_PRIVS A
LEFT OUTER JOIN
information_schema.USER_PRIVILEGES B
ON (A.PRIVILEGE=B.PRIVILEGE_TYPE AND replace(B.GRANTEE,'''','')=current_user())
) as X where TABLE_CATALOG is null) as Y group by \`ONE\`;
if @HAS_SUPER='NONE' THEN
 IF @MISSING_PRIVS != 'NONE'  THEN

  SELECT concat('Insufficient privileges. Grant ',@MISSING_PRIVS,' on *.* to ',CONCAT('\'',REPLACE(CURRENT_USER(),'@','\'@\''),'\'')) as NOTE;

 END IF; 
END IF;
end;
//
delimiter ;"
  if [ ! "$BYPASS_PRIV_CHECK" == "TRUE" ]; then
      ERR=$($CMD_MARIADB $CLOPTS -Ae "$SQL")
      if [ "$ERR" ]; then die "$ERR"; fi
  fi
}

display_final_message(){
if [ -f "${LOG_FILE}" ]; then
 TEMP_COLOR=lmagenta; print_color "\nThe logfile ${LOG_FILE} contains the details from running this script.\n\n"; unset TEMP_COLOR;
 TEMP_COLOR=lcyan;   print_color "Elapsed time: "; unset TEMP_COLOR; printf "${SECONDS} seconds\n";
 TEMP_COLOR=lcyan;   print_color "Binlog Events Skipped: "; unset TEMP_COLOR; printf "${SKIPPED_EVENTS}\n\n";
 if [ ! $NOLOG ]; then
   printf "\nElapsed time: ${SECONDS} seconds\n" >> ${LOG_FILE};
   printf "Binlog Events Skipped: ${SKIPPED_EVENTS}\n\n"  >> ${LOG_FILE};
 fi
fi
}

for params in "$@"; do
unset VALID; #REQUIRED
# echo "PARAMS: $params"
if [ $(echo "$params"|sed 's,=.*,,') == '--skip_multiplier' ]; then 
  MLTP=$(echo "$params" | sed 's/.*=//g'); 
  if [ ! $(echo $MLTP | awk '{ if(int($1)==$1) print $1}') ]; then 
   INVALID_INPUT="$params"; 
  else 
   VALID=TRUE; 
  fi
fi
if [ $(echo "$params"|sed 's,=.*,,') == '--milliseconds' ]; then 
  MLLS=$(echo "$params" | sed 's/.*=//g'); 
  if [ ! $(echo $MLLS | awk '{ if(int($1)==$1) print $1}') ]; then 
   INVALID_INPUT="$params"; 
  else 
   VALID=TRUE; 
  fi
fi
if [ $(echo "$params"|sed 's,=.*,,') == '--conn_name' ]; then
  CONN_NAME=$(echo "$params" | sed 's/.*=//g');
  if [ "$CONN_NAME" == '--conn_name' ]; then unset CONN_NAME; fi
  if [ ! $CONN_NAME ]; then
   INVALID_INPUT="$params";
  else
   VALID=TRUE;
  fi
fi
  if [ "$params" == '--bypass_priv_check' ]; then BYPASS_PRIV_CHECK='TRUE'; VALID=TRUE; fi
  if [ "$params" == '--cleanup' ]; then CLEANUP='TRUE'; VALID=TRUE; fi
  if [ "$params" == '--version' ]; then DISPLAY_VERSION=TRUE; VALID=TRUE; fi
  if [ "$params" == '--test' ]; then DISPLAY_VERSION=TRUE; VALID=TRUE; fi
  if [ "$params" == '--help' ]; then HELP=TRUE; VALID=TRUE; fi
  if [ "$params" == '--nolog' ]; then NOLOG=TRUE; VALID=TRUE; fi
  if [ "$params" == '--nocolor' ]; then NOCOLOR=TRUE; VALID=TRUE; fi  
  if [ ! $VALID ] && [ ! $INVALID_INPUT ];  then  INVALID_INPUT="$params"; fi
done
if [ $INVALID_INPUT ]; then HELP=TRUE; fi


if [ $(_which mariadb 2>/dev/null) ]; then
  CMD_MARIADB="${CMD_MARIADB:-"$(_which mariadb)"}"
else
  CMD_MARIADB="${CMD_MYSQL:-"$(_which mysql)"}"
fi

CMD_MY_PRINT_DEFAULTS="${CMD_MY_PRINT_DEFAULTS:-"$(_which my_print_defaults)"}"

if [ -z $CMD_MARIADB ]; then
  die "mariadb client command not available."
fi

if [ -z $CMD_MY_PRINT_DEFAULTS ]; then
#  die "my_print_defaults command not available."
  CMD_MY_PRINT_DEFAULTS=${SCRIPT_DIR}/bin/my_print_defaults
fi

CLOPTS=$($CMD_MY_PRINT_DEFAULTS --defaults-file=$CONFIG_FILE start_replica_assistant | sed -z -e "s/\n/ /g")
if [ "$(find $SQL_DIR/ -type f -name "*.sql" | wc -l)" == "0" ]; then die "No SQL files to run! Place some SQL scripts into the SQL directory."; fi

