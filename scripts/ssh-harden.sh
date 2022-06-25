#!/bin/bash/env bash

# A script to harden sshd_config , part of harden project


[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x


# Print startup message with run time settings. 
echo >&2 "\
SSH Hardening is starting at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

echo -e "\SSH Hardening Script is running .. "

RUNTIME_DATE=$(date +%F_%H:%M:%S)
SCRIPT_NAME=`basename $0`
PARAMETERS_FILE="$MAIN_DIR/resources/sshd_conf.txt"
SSH_ACTIONS_FILE="/usr/share/harden/actions/ssh-actions.sh"


#Cheking the Acceptance of ssh-hardening Checks: 
if [[$(_check_profile_file_function ssh check) -ne 1 ]] ; then 
echo "$RUNTIME_DATE:$SCRIPT_NAME:Terminates, Checking is now allowed"
exit
fi


#Fetching the Actions User's Acceptance.
GENERAL_ACTIONS_ACCEPTENCE=$(_check_profile_file_function ssh action )

#Cheking the Acceptance of ssh-hardening Actions: 
[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo -e "#!/usr/bin/env bash" >> $SSH_ACTIONS_FILE






[[ $(_check_profile_file_function check) == 0 ]] && exit

cat $PARAMETERS_FILE | while read line || [[ -n $line ]];
do
   PARA=$(echo $line | awk '{print $1;}')           # the first field of parameters file is the option 
   RECOM_VAL=$(echo $line | awk '{print $2;}')           # the second is the recommended value 
   MESSAGE=$(echo $line | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')  # the rest of the line is the message 

   [[ $(_check_profile_file_function check) == 0 ]]  && continue	# Skip checking this parameter if profile file says so

   CURRENT=$(grep -i "$PARA" /etc/ssh/sshd_config)
   CURRENT_VAL=$(echo $CURRENT | awk '{print $NF}')
     
   [[ -z $CURRENT_VAL ]]  && continue


   [[ $CURRENT_VAL != $RECOM_VAL ]] && echo "ssh-parameter-Hardening[$PARA]: (recommended value = $RECOM_VAL // current value = $CURRENT_VAL). $MESSAGE" >> "$MESSAGES_FILE" 

   
   # echo "Option $RECOM_PAR is set to $CURRENT_VAL" >> $STATUS_FILE
   
   [[ $(_check_profile_file_function action) == 0 ]]  && continue	# Skip actions for this parameter if profile file says so
   echo "sed -i -e "/.*$CURRENT*./ s/.*/$PARA $RECOM_VAL/" /etc/ssh/sshd_config" >> $SSH_ACTIONS_FILE

done

if [[ $(_check_profile_file_function check) == 1 ]]
then 

ALLOWED=$(grep -i "AllowUsers" /etc/ssh/sshd_config)
ALLOWED_VAL=$(echo $ALLOWED | awk '{print $NF}')

[[ -n $ALLOWED_VAL ]]  && echo "ssh-parameter-Hardening[AllowUsers]:You didn't define any user for the AllowUsers option, \
This keeps off any other users who might try to gain entry to your system without your approval \
it's recommended to define the users who require ssh connection here. " >> $MESSAGES_FILE 

fi


if [[ $(_check_profile_file_function check) == 1 ]]
then 

PORT=$(grep -i "port" /etc/ssh/sshd_config)
PORT_VAL=$(echo $PORT | awk '{print $NF}')

[[ $PORT_VAL == 22 ]]  && echo "ssh-parameter-Hardening[port]:(recommended value = not the default(22) // current value = $PORT_VAL).change from the default(22) to make it a bit harder for the bad guys, you can change it to what you want. " >> $MESSAGES_FILE 

[[ $(_check_profile_file_function action) == 0 ]]  && exit	# Skip actions for this parameter if profile file says so
echo "sed -i -e "/.*$PORT*./ s/.*/port 2234/" /etc/ssh/sshd_config" >> $SSH_ACTIONS_FILE

fi

if [[ $(_check_profile_file_function check) == 1 ]]
then 

MaxAuthTries=$(grep -i "MaxAuthTries" /etc/ssh/sshd_config)
MaxAuthTries_VAL=$(echo $MaxAuthTries | awk '{print $NF}')

(( $MaxAuthTries_VAL >= 5 ))  && echo "ssh-parameter-Hardening[MaxAuthTries]:(recommended value = Below 5 // current value = $MaxAuthTries_VAL).limiting the number of SSH login attempts such that after a number of failed attempts, the connection drops, 3 is usually good but you can change it to what suit your needs. " >> $MESSAGES_FILE 

[[ $(_check_profile_file_function action) == 0 ]]  && exit	# Skip actions for this parameter if profile file says so
echo "sed -i -e "/.*$MaxAuthTries*./ s/.*/MaxAuthTries 3/" /etc/ssh/sshd_config" >> $SSH_ACTIONS_FILE

fi


echo "systemctl restart sshd" >> $SSH_ACTIONS_FILE # restart the service so the changes take place

[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo $SSH_ACTIONS_FILE >> $ACTIONS_FILE    # Add approved actions to the actions file


echo -e "\nSSH Hardening script has finished...\n"