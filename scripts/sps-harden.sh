#!/bin/bash/env bash 


[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x


# Print startup message with run time settings. 
echo >&2 "\
SPS Hardening is starting at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

echo -e "\SPS Hardening Script is running .. "

RUNTIME_DATE=$(date +%F_%H:%M:%S)
SCRIPT_NAME=`basename $0`
PARAMETERS_FILE_S="$MAIN_DIR/resources/sps_conf.txt"
PARAMETERS_FILE_C="$MAIN_DIR/resources/sc_conf.txt"
SPS_ACTIONS_FILE="/usr/share/harden/actions/sps-actions.sh"


#Cheking the Acceptance of sps-hardening Checks: 
if [[ $(_check_profile_file_function sps check) -ne 1 ]] ; then 
echo "$RUNTIME_DATE:$SCRIPT_NAME:Terminates, Checking is now allowed"
exit
fi


#Fetching the Actions User's Acceptance.
GENERAL_ACTIONS_ACCEPTENCE=$(_check_profile_file_function sps action)

#Cheking the Acceptance of sps-hardening Actions: 
[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo -e "#!/usr/bin/env bash" >> $SPS_ACTIONS_FILE







cat $PARAMETERS_FILE_S | while read line || [[ -n $line ]];
do  
    SERVICE=$(echo $line | awk '{print $1;}')
    RECOM_PAR_S=$(echo $line | awk '{print $2;}')
    RECOM_VAL_S=$(echo $line | awk '{print $3;}')
    MESSAGE_S=$(echo $line | awk '{for (i=4; i<NF; i++) printf $i " "; print $NF}')
    
    [[ $(_check_profile_file_function check) == 0 ]]  && continue
    
    CURRENT_S=$(systemctl is-enabled $RECOM_PAR_S)

    [[ -z $CURRENT_S ]]  && continue

    [[ $CURRENT_S != $RECOM_VAL_S ]] && echo "SERVICE-Hardening[$SERVICE]: (recommended value = $RECOM_VAL_S // current value = $CURRENT_S). $MESSAGE_S" >> "$MESSAGES_FILE"


    [[ $(_check_profile_file_function action) == 0 ]]  && continue

    echo "systemctl disable $RECOM_PAR_S" >> $SPS_ACTIONS_FILE
done

cat $PARAMETERS_FILE_C | while read line || [[ -n $line ]];
do
    CLIENT=$(echo $line | awk '{print $1;}')
    RECOM_PAR_C=$(echo $line | awk '{print $2;}')
    MESSAGE_C=$(echo $line | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')
    
    [[ $(_check_profile_file_function rc check) == 0 ]]  && continue

    CURRENT_C=$(rpm -q $RECOM_PAR_C | awk '{for (i=4; i<NF; i++) printf $i " "; print $NF}')

    
    [[ -z $CURRENT_C ]]  && continue

    [[ $CURRENT_C != "not installed" ]] && echo "ClIENT-Hardening[$CLIENT]: (recommended value = $RECOM_VAL_C // current value = $CURRENT_C). $MESSAGE_C" >> "$MESSAGES_FILE"
    
    [[ $(_check_profile_file_function rc action) == 0 ]]  && continue
    echo "yum -y remove $RECOM_PAR_C" >> $SPS_ACTION_FILE


done


[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo $SPS_ACTIONS_FILE >> $ACTIONS_FILE    # Add approved actions to the actions file


echo -e "\nSPS Hardening script has finished...\n"