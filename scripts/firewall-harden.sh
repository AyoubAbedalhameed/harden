
#!/usr/bin/env bash

#This script is a part of harden project, it will be used for hardening auditd with recommended rules.
#Auditd hardening by checking the status of audit package and checking the deployment of predefined auditd rules.

#Written By: Ayoub Abedalhameed (aasedqiabedalhameed173@cit.just.edu.jo)



#Prevent overwriting files 
set -C



#Checking the execution case, (whether the script has been called by the hardening main module)
[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called by harden-main"
	exit 1
}

#Checking __DEBUG_X varibale, if it has been set in the caller script then set -x for debugging. 
[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings. 
echo >&2 "\
auditd Hardening is starting at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

echo -e "\nFirewall Hardening Script is running .. "





#Fetching Script run time. 
RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time
SCRIPT_NAME=`basename $0`
SOURCE_FILE="$MAIN_DIR/resources/iptables-rules.rc"
DEBUG=0				#Used for debugging, (only for this script)
FIREWALL_ACTION_FILE="/usr/share/harden/actions/firewall-action.sh"

#Importing firewall rules: 
source "$MAIN_DIR/resources/iptables-rules.rc"



#Extracting script profile from the systemm profile file. 
PROFILE=$(jq '.[] | select(.name=="firewall")' $PROFILE_FILE)	# Save our object from the array



#Cheking the Acceptance of firewall-hardening Checks: 
if [[ `echo $PROFILE | jq '.firewall.check' ` -ne 1 ]] ; then 
echo "$RUNTIME_DATE:$SCRIPT_NAME:Terminates, Checking is now allowed"
exit
fi


#Fetching the Actions User's Acceptance.
GENERAL_ACTIONS_ACCEPTENCE=$( echo $PROFILE | jq '.firewall.action' )

#Cheking the Acceptance of firewall-hardening Actions: 
[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo -e "#!/usr/bin/env bash" >> $FIREWALL_ACTION_FILE




#Functions Definitions: 

## To query a value from JSON profile file
check-pf()  { return $(echo $PROFILE | jq ".firewall.$1.$2");  }

## ReplaceParameters() function, used to add the user parameters to the iptables rule.
 ReplaceParameters () 
{ #Usage: ReplaceParameter <RulesCount> <RuleName> <ParametersList> 
													

	for (( i=1; i<=$1 ; i++ )) ; do 	  #
	
    	local Temp="${FW_Rules["$2,$i"]}" #Fetching the current Rule from the rules dictionary. 
    	[[ "$3" == "null" ]]  && echo "$Temp\n" && continue ; #If the parameters list is null, replace nothing.
    	local PARAMETERS_COUNTER=0		 	 #Used as index do define the current parameter number in the loop.
   		 for PARAMETER in $3 ; do
														
        	Temp=$( echo $Temp | sed "s/@${PARAMETERS_COUNTER}/${PARAMETER//'/'/\\/}/g" )  #Replacing all occurrences for the current parameter in the current string. 
        	PARAMETERS_COUNTER=$( expr $PARAMETERS_COUNTER + 1 ) 				  #increment the param index. 		

    	done
    PARAMETERS_COUNTER=0
    echo "$Temp\n"
 
	done 
}


## check_rule function, used to the the existence of a list of rules (line separated) from the standard stream.
check_rule()
{ #Usage: STREAM | check_rule 

	local RULES=$(</dev/stdin)
						[[ $DEBUG -eq 1 ]] && echo -e "check_rule: Looping on rules\n"

	while read RULE ; do
    	                [[ $DEBUG -eq 1 ]] && echo "check_rule:loop: current rule is ($RULE)"
    	iptables -C `echo $RULE`
    	RULE_STATUS=$?
    	                [[ $DEBUG -eq 1 ]] && echo "check_rule:loop: current rule status is $RULE_STATUS"
    	[[ $RULE_STATUS -ne 0 ]] && return 0
    done <<< "$RULES"
    
	return 1
}


#write_action Function, used to echo the required commands to apply rules. 
write_action(){

	local RULES=$(</dev/stdin)
	                    				 [[ $DEBUG -eq 1 ]] && echo "write_action is running"
	
	while read RULE ; do
    	               					 [[ $DEBUG -eq 1 ]] && echo "The rule is $RULE"
    	echo -e "iptables -A $RULE" >> $FIREWALL_ACTION_FILE
    done <<< "$RULES"
    
	}



	#Cheking Firewall Services: 
	CHECK_FIREWALL_SERVICES(){

	local Flag=1 
	IPTABLES_NEW_INSTALLATION=0


	#Checking Firewalld Service:  
	echo "$SCRIPT_NAME:Checking firewalld service status" >&2 
	systemctl status firewalld >/dev/null
	firewalld_status=$?

	if [[ ! $firewalld_status -eq  4 ]] ; then 
	firewalld_enabled=$(systemctl is-enabled firewalld)
	firewalld_active=$(systemctl is-active firewalld) ; Flag=$? 
	firewalld_installed=1
	else firewalld_enabled="disabled" ; firewalld_active="inactive" ; firewalld_installed=0; fi 

	[[ ($GENERAL_ACTIONS_ACCEPTENCE -eq 1) && ($firewalld_enabled == "enabled") ]] && echo "systemctl disable firewalld" >> $ACTIONS_FILE
	[[ ($GENERAL_ACTIONS_ACCEPTENCE -eq 1) && ($firewalld_active -eq 1) ]] && echo "systemctl stop firewalld" >> $ACTIONS_FILE

	#Cheking Iptables Service:  
	echo "$SCRIPT_NAME: Checking iptables service status" >&2
	systemctl status iptables > /dev/null
	iptables_status=$? 

	if [[ ! $iptables_status -eq  4 ]] ; then 
	iptables_enabled=$(systemctl is-enabled iptables)  || echo "systemctl enable iptables" >> $ACTIONS_FILE
	iptables_active=$(systemctl is-active iptables); Flag=$? ; [[ $Flag -ne 0 ]] && echo "systemctl start iptables" >> $ACTIONS_FILE
	iptables_installed=1
	else iptables_enabled="disabled" ; iptables_active="inactive" ; iptables_installed=0 ; fi 


	if [[ iptables_installed -eq 0 && firewalld_installed -eq 0 ]] 
	then echo "$SCRIPT_NAME:$RUNTIME_DATE No Firewall Service Installed on this machine, at least one firewall service should be running" >> $MESSAGES_FILE
	NoFireWall=0 ; fi


	[[ $Flag -ne 0 ]] && echo "$SCRIPT_NAME:$RUNTIME_DATE Firewall services are not enabled on this machine, you should enable one firewall service at least on your system" >> $MESSAGES_FILE 
}


CHECK_FIREWALL_SERVICES
iptables_installed=1


#Intsalling iptables if it is not installed: 
if [[ (iptables_installed -ne 1) && (GENERAL_ACTIONS_ACCEPTENCE -eq 1) ]] ; then 
									[[ $DEBUG -eq 1 ]] && echo "$SCRIPT_NAME:$RUNTIME_DATE: Installing iptables .. "
	yum -y install iptables >&2 && IPTABLES_NEW_INSTALLATION=1
	yum list installed  | grep "iptables-services" && iptables_installed=1 && echo "$SCRIPT_NAME:$RUNTIME_DATE: iptables is installed succesfully" >> $MESSAGES_FILE
	
fi



if [[ iptables_installed -ne 1 ]] ; then 

    echo "$SCRIPT_NAME: iptables is not installed, iptables rules checking will be skipped" >&2
    exit
fi


#Checking iptables filter-table Policy:

#INPUT chain  
iptables -S | grep "\-P INPUT DROP" ; POLICY_STATUS=$?
if [[ $POLICY_STATUS -ne 0 ]]; then 
	echo "$SCRIPT_NAME : $RUNTIME_DATE : POLICY NOT MATCHED : The current iptables policy for the INPUT chain is ACCEPT but the recommended policy is DROP" >> $MESSAGES_FILE
	echo "iptables -P INPUT DROP" >> $ACTIONS_FILE
fi

#OUTPUT chain: 
iptables -S | grep "\-P OUTPUT DROP"  ; POLICY_STATUS=$? 
if [[ $POLICY_STATUS -ne 0 ]]; then 
	echo "$SCRIPT_NAME : $RUNTIME_DATE : POLICY NOT MATCHED : The current iptables policy for the OUTPUT chain is ACCEPT but the recommended policy is DROP"	>> $MESSAGES_FILE	 
	echo "iptables -P OUTPUT DROP" >> $ACTIONS_FILE
fi
 

#FORWARD chain: 
iptables -S | grep "\-P FORWARD DROP"  ; POLICY_STATUS=$? 
if [[ $POLICY_STATUS -ne 0 ]]; then 
	echo "$SCRIPT_NAME : $RUNTIME_DATE : POLICY NOT MATCHED : The current iptables policy for the FORWARD chain is ACCEPT but the recommended policy is DROP" >>	$MESSAGES_FILE
	echo "iptables -P FORWARD DROP" >> $ACTIONS_FILE
fi
 



RULE_STATUS=0 

#Iterating over the keys of the iptables-rules (Rules Names): 
for RULE in $( echo "${!FW_Rules[@]}" | sed 's/[a-z\0-9\.\_\-]*,[d\1-9]//g' ); do
                
                            [[ $DEBUG -eq 1 ]] && echo -e "\nChecking new rule:\n"
                            
    COUNTER=${FW_Rules[$RULE]} #Fetching the rule's counter which indicates the number of child rules for the current rule
                            [[ $DEBUG -eq 1 ]] && echo "rules Counter = $COUNTER"
    RULE=${RULE%,*}	        # Substring from the begging to the comma (,) to get the parameter name without the index
                            [[ $DEBUG -eq 1 ]] && echo "rules key is: = ($RULE)"
    check-pf ${RULE} check     #Fetching the Used Acceptance for the current rule from the profile file.
    USER_CHECK_ACCEPTENCE=$?
	
	check-pf ${RULE} action
	USER_ACTION_ACCEPTENCE=$?

                            [[ $DEBUG -eq 1 ]] && echo "RULE User Checking Acceptance = $USER_CHECK_ACCEPTENCE"
							[[ $DEBUG -eq 1 ]] && echo "RULE User Action Acceptance = $USER_ACTION_ACCEPTENCE"

    #Checking whether the rule is accepted, if it not just print a message and continue;                         
    if [[ $USER_CHECK_ACCEPTENCE == 0 ]] ; then echo "$SCRIPT_NAME: ($RULE) RULE NOT ACCEPTED. skipping this rule" >&2 ; continue ; fi
                           
                            [[ $DEBUG -eq 1  ]] && echo "Rule Accepted ($RULE)"


    PARAMETERS_LIST=$( echo $PROFILE |  jq -r ".firewall.$RULE.parameters" ) #Fetching Rule's Parameters from the profile file.

                            [[ $DEBUG -eq 1  ]] && echo "parameters list: (${PARAMETERS_LIST})"

	#Fetching the Description from the rules dictionary ;
    DESCRIPTION=${FW_Rules["$RULE,d"]}
                            [[ $DEBUG -eq 1  ]] && echo "rules description: ($DESCRIPTION)"

    #Adding the parameters to the rules before checking them. 
    FINAL_RULE=$( ReplaceParameters $COUNTER $RULE "${PARAMETERS_LIST}" )

                            [[ $DEBUG -eq 1  ]] && echo -e "rules with replaced parameters: \n$FINAL_RULE\n"
                            [[ $DEBUG -eq 1  ]] && echo -e "Calling check_rule to checking Previous rules .. \n"

    #Pipping the rules to the check_rule function to fetch RULE_STATUS
    if [[ $IPTABLES_NEW_INSTALLATION -ne 1 ]] ; then 
		echo -e $FINAL_RULE | check_rule 
    	RULE_STATUS=$?

 	fi  


	#Checking RULE_STATUS
    if [[ RULE_STATUS -ne 1 ]] ; then 

							[[ $DEBUG -eq 1  ]] && echo -e "\nRULE NOT MATCHED, logging message"

		echo -e "\n$SCRIPT_NAME:  [$RULE]  RULE NOT MATCHED  $DESCRIPTION" >> $MESSAGES_FILE 
		[[ (USER_ACTION_ACCEPTENCE -eq 1)  && (GENERAL_ACTIONS_ACCEPTENCE -eq 1) ]] && echo -e $FINAL_RULE | write_action
	fi
done

[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo "$FIREWALL_ACTION_FILE" >> $ACTIONS_FILE


echo -e "\nFirewall Hardening script has finished...\n"