#!/bin/bash/env bash

# A script to harden unbound_config , part of harden project
[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x


# Print startup message with run time settings. 
echo >&2 "\
DNS Hardening is starting at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

echo -e "\DNS Hardening Script is running .. "

RUNTIME_DATE=$(date +%F_%H:%M:%S)
SCRIPT_NAME=`basename $0`
PARAMETERS_FILE_U="$MAIN_DIR/resources/unbound_conf.txt"
private_address="$MAIN_DIR/resources/private.txt"
DNS_ACTIONS_FILE="/usr/share/harden/actions/dns-actions.sh"

#Cheking the Acceptance of dns-hardening Checks: 
if [[ $(_check_profile_file_function dns check ) -ne 1 ]] ; then 
echo "$RUNTIME_DATE:$SCRIPT_NAME:Terminates, Checking is now allowed"
exit
fi


#Fetching the Actions User's Acceptance.
GENERAL_ACTIONS_ACCEPTENCE=$(_check_profile_file_function dns action )

#Cheking the Acceptance of dns-hardening Actions: 
[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo -e "#!/usr/bin/env bash" >> $DNS_ACTIONS_FILE





if [[ $(systemctl is-active unbound) == "inactive" ]] && [[ $(_check_profile_file_function install action) == 1 ]]
then 
    yum -y install unbound
    systemctl start unbound 
    systemctl enable unbound 
fi 



cat $PARAMETERS_FILE_U | while read line || [[ -n $line ]];
do 
    PARA_U=$(echo $line | awk '{print $1;}')           # the first field of parameters file is the option 
    RECOM_VAL_U=$(echo $line | awk '{print $2;}')           # the second is the recommended value 
    MESSAGE_U=$(echo $line | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')  # the rest of the line is the message 

    [[ $(_check_profile_file_function parameter check) == 0 ]]  && continue

    CURRENT_U=$(grep -i "$PARA_U" /etc/unbound/unbound.conf)
    CURRENT_VAL_U=$(echo $CURRENT_U | awk '{print $NF}')
    
    [[ -z $CURRENT_VAL_U ]]  && continue 

    [[ $CURRENT_VAL_U != $RECOM_VAL_U ]] && echo "DNS-Hardening[$PARA_U]: (recommended value = $RECOM_VAL_U // current value = $CURRENT_U). $MESSAGE_U" >> "$MESSAGES_FILE"
    

    [[ $(_check_profile_file_function parameter action) == 0 ]]  && continue

    echo "sed -i -e "/.*$CURRENT_U*./ s/.*/   $PARA_U: $RECOM_VAL_U/" /etc/unbound/unbound.conf" >> $DNS_ACTIONS_FILE


done 

matches=$(grep -c "private-address:" /etc/unbound/unbound.conf)

for i in {1..$matches}
do 
    pri_add_line=$(grep -m$i "private-address:" /etc/unbound/unbound.conf | tail -n1)
    pri_add=$(echo $pri_add_line | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')
    
    [[ $(_check_profile_file_function private check) == 0 ]]  && continue

    exist=$(grep -i "$pri_add" $private_address)
    
    [[ -n $exist ]] && sed -i -e "/.*$exist*./ s/.*/$pri_add yes/" $private_address

    if [[ -z $exist ]] 
    then 
        echo "DNS-Hardening[private address]:The private address $pri_add is not a private network address, the private-address parameter specifies \
private network addresses are not allowed to be returned for public internet names. Any  occurrence of such addresses are removed from DNS \
answers. Additionally, the DNSSEC validator may mark the answers bogus. " >> $MESSAGES_FILE
    
    
    [[ $(_check_profile_file_function private action) == 0 ]]  && continue
    echo "sed '/$pri_add_line/d' /etc/unbound/unbound.conf" >> $DNS_ACTIONS_FILE
    
    fi
done

[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo $DNS_ACTIONS_FILE >> $ACTIONS_FILE


echo -e "\nDNS Hardening script has finished...\n"

