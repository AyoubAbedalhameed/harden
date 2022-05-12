#!/usr/bin/env bash
#This script is a part of harden project, it will be used for hardening linux firewall with recommended rules.

#Prevent overwriting files
set -C

#Fetching run time. 
RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time

echo "$RUNTIME_DATE:$0   script is running .. "




# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
	case $1 in
		-md|--main-directory)
			MAIN_DIR=$2
			shift 2
			;;
		-pf|--profile-file)
			PROFILE_FILE=$2
			shift 2
			;;
		-sf|--status-file)	# Use a configuration file from user choice
			STATUS_FILE=$2
			shift 2
			;;
		-mf|--messages-file)	# Use/Create a messages file from user choice
			MESSAGES_FILE=$2
			shift 2	# shift the arguments 2 times (we used two arguments)
			;;
		-af|--actions-file)	# Use/Create an actions file from user choice
			ACTIONS_FILE=$2
			shift 2
			;;
		-*|--*)
			echo "Unknown option $1"
			usage
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1")	# save positional arguments
			shift
			;;
	esac
done



# Restore Positional Arguments (those which has not been used)
set -- "${POSITIONAL_ARGS[@]}"




# ? 

#MAIN_DIR=${MAIN_DIR:="/usr/share/harden"}
#PROFILE_FILE=${PROFILE_FILE:="/etc/harden/admin-choice.profile"}    # Use Default User Choice Profile File, 
                                                                    # if not set by a positional parameter (command line argument)
#STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/$RUNTIME_DATE.status"} # Currently used status file
#MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}  # Currently used messages file
#ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}  # Currently used Actions file






STATUS_FILE=$1
MESSAGES_FILE=$2
ACTIONS_FILE=$3


#Cheking Firewall Services: 

Flag=1 


#Checking Firewalld Service:  
echo "$RUNTIME_DATE:$0:Checking firewalld service status" 
systemctl status firewalld
firewalld_status=$?

if [[ ! $firewalld_status -eq  4 ]] ; then 
firewalld_enabled=$(systemctl is-enabled firewalld) 
firewalld_active=$(systemctl is-active firewalld) ; Flag=$? 
firewalld_installed=0
else firewalld_enabled="disabled" ; firewalld_active="inactive" ; firewalld_installed=1; fi 


#Cheking Iptables Service:  
echo "$RUNTIME_DATE:$0:Checking firewalld service status" 
systemctl status iptables 
iptables_status=$? 

if [[ ! $iptables_status -eq  4 ]] ; then 
iptables_enabled=$(systemctl is-enabled iptables) ; echo $iptables_enabled
iptables_active=$(systemctl is-active iptables); Flag=$?
iptables_installed=0 
else iptables_enabled="disabled" ; iptables_active="inactive" ; iptables_installed=1 ; fi 


echo "$0.firewalld.installed $firewalld_installed" >> $STATUS_FILE
echo "$0.firewalld.enabled $firewalld_enabled" >> $STATUS_FILE 
echo "$0.firewalld.active $firewalld_active " >> $STATUS_FILE

echo "$0.iptables.installed $iptables_installed" >> $STATUS_FILE
echo "$0.iptables.enabled $iptables_enabled" >> $STATUS_FILE
echo "$0.iptabled.active $iptables_active" >> $STATUS_FILE




if [[ iptables_installed -eq 1 && firewalld_installed -eq 1 ]] 
then echo "$0:$RUNTIME_DATE No Firewall Service Installed on this machine, at least one firewall service should be running" >> $MESSAGES_FILE
NoFireWall=0 ; fi


[[ $Flag -ne 0 ]] && echo "$0:$RUNTIME_DATE No Firewalld Service is running on this machine, you should enable one firewall at least on your system" >> $MESSAGES_FILE 