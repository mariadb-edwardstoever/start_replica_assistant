#!/usr/bin/env bash
# start_replica_assistant.sh Start Replica Assistant
# By Edward Stoever for MariaDB Support

### DO NOT EDIT SCRIPT. 
### FOR FULL INSTRUCTIONS: README.md
### FOR BRIEF INSTRUCTIONS: ./start_replica_assistant.sh --help


# Establish working directory and source pre_assist.sh 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source ${SCRIPT_DIR}/vsn.sh
source ${SCRIPT_DIR}/pre_assist.sh 

display_title
start_message
check_required_privs
gtid_strict_mode_at_script_start
# master_use_gtid_at_script_start
is_there_one_named_connection
set_slave_status_vars

is_replica
no_errors

while [[ "$IO_ERRNO" != "0" || "$SQL_ERRNO" != "0" ]]; do

check_request_response
display_error_skip_message

################## INPUT OPTIONS #######################
if [ $REQUEST_RESPONSE ]; then read -s -n 1 RESPONSE; fi
case "$RESPONSE" in 
   c)
   skip_this_err
   set_slave_status_vars
   unset RESPONSE
;;

   a)
   skip_list
   skip_this_err
   set_slave_status_vars
   unset RESPONSE
;;

   e)
   skip_everything
   skip_this_err
   set_slave_status_vars
   unset RESPONSE
;;
   *)
   echo "exiting..."
   break
;;
esac
########################################################

done

final_check_for_slave_error
set_sql_slave_skip_counter_to_zero
return_gtid_strict_mode_to_start_value
return_master_use_gtid_to_start_value
display_report
display_final_message