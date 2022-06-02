#!/bin/bash
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



echo -e "\nAuditd Hardening Script is running .. "


#Fetching Script run time. 
RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time

#Script special variables.
AUDITD_ACTIONS_FILE="/usr/share/harden/actions/auditd-actions.sh"
SCRIPT_NAME=`basename $0`
ADDED_AUDIT_RULES_FILE="$MAIN_DIR/resources/harden-custom-audit.rules"

DEBUG=0	#Used for debugging, (only for this script)


#Importing auditd rules: 
source "$MAIN_DIR/resources/audit-rules.rc"


#Extracting script profile from the systemm profile file. 
PROFILE=$(jq '.[] | select(.name=="auditd")' $PROFILE_FILE)	# Save our object from the array


#Cheking the Acceptance of auditd-hardening Checks: 
if [[ `echo $PROFILE | jq '.auditd.check' ` -ne 1 ]] ; then 
	echo "$RUNTIME_DATE:$SCRIPT_NAME:Terminates, Checking is not allowed"
	exit
fi


#Fetching the Actions User's Acceptance.
GENERAL_ACTIONS_ACCEPTENCE=$( echo $PROFILE | jq '.auditd.action' )


#Adding -c option at the beggining of the harden-custom-audit.rules to Continue loading rules in spite of an error when (augenrules) runs.
#Do not stop on error 
[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]]	&& echo "-c" >> $ADDED_AUDIT_RULES_FILE


 
#Functions Definitions: 

## To query a value from JSON profile file
check-pf()  { return $(echo $PROFILE | jq ".auditd.$1.$2");  }


## ReplaceParameters() function, used to add the user parameters to the iptables rule.
 ReplaceParameters () 
{ #Usage: ReplaceParameter <RulesCount> <RuleName> <ParametersList> 
													

	for (( i=1; i<=$1 ; i++ )) ; do 	  #
	
    	local Temp="${audit_rules["$2,$i"]}" #Fetching the current Rule from the rules dictionary. 
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
	local RULE_STATUS=1
    
                                        [[ $DEBUG -eq 1 ]] && echo -e "check_rule is running, Local Rules are \n ($RULES)"

	while read RULE ; do
    	                                [[ $DEBUG -eq 1 ]] && echo "check_rule: current rule is ($RULE)"

    	if [[ $AUDITD_NEW_INSTALLATION -ne 1 ]] ; then 
			echo "$CURRENT_AUDIT_RULES" | grep -Fxe "$RULE"
		    RULE_STATUS=$?
		fi
    
        if [[ $RULE_STATUS -eq 1 ]] ; then 
            echo "$SCRIPT_NAME: [$PARAM]  ($RULE)  RULE NOT MATCHED. $DESCRIPTION" >> $MESSAGES_FILE
            [[ ($USER_ACTION_ACCEPTENCE -eq 1) && ($GENERAL_ACTIONS_ACCEPTENCE -eq 1) ]] && echo "$RULE" >> $ADDED_AUDIT_RULES_FILE 
        fi
    	                                [[ $DEBUG -eq 1 ]] && echo "check_rule: Rule status $RULE_STATUS"
    	
    done <<< "$RULES"
    
	return
}

#Checking the existence and status of auditd. 
#Cheking auditd Service:  

                                [[ $DEBUG -eq 1 ]] && echo "$SCRIPT_NAME: Checking firewalld service status" 
systemctl status auditd >&2
AUDITD_STATUS=$? 

if [[ ! $AUDITD_STATUS -eq  4 ]] ; then 
	AUDITD_ENABLED=$(systemctl is-enabled auditd)  || echo "service auditd enable" >> $AUDITD_ACTIONS_FILE
	AUDITD_ACTIVE=$(systemctl is-active auditd); Flag=$? ; [[ $Flag -ne 0 ]] && echo "service auditd start" >> $AUDITD_ACTIONS_FILE
	AUDITD_INSTALLED=1
	else AUDITD_ENABLED="disabled" ; AUDITD_ACTIVE="inactive" ; AUDITD_INSTALLED=0 
fi 



#Intsalling auditd if it is not installed: 
if [[ (AUDITD_INSTALLED -ne 1) && (GENERAL_ACTIONS_ACCEPTENCE -eq 1) ]] ; then 
									[[ $DEBUG -eq 1 ]] && echo "$SCRIPT_NAME : Auditd is not installed"
	yum -y install audit>&2 && AUDITD_NEW_INSTALLATION=1
	yum list installed  | grep "audit." && AUDITD_INSTALLED=1 && echo >&2 "$SCRIPT_NAME[service-status]: auditd has not been installed succesfully"
	
fi


if [[ AUDITD_INSTALLED -ne 1 ]] ; then 

    echo "$SCRIPT_NAME: auditd installation failed, auditd rules checking will be skipped"
    exit
fi



#Fetching current auditd rules: 
augenrules --load >&2
CURRENT_AUDIT_RULES=`cat /etc/audit/audit.rules`


for PARAM in $( echo "${!audit_rules[@]}" | sed 's/[a-z\0-9\.\_\-]*,[d\1-9]//g' | sed 's/ [0-9]//g'); do
                
                            [[ $DEBUG -eq 1 ]] && echo "----------------------NEW_RULE_CHAIN---------------------------"
                            [[ $DEBUG -eq 1 ]] && echo "RULE_CHAIN: KEY_NAME= ($PARAM)"
                            
    COUNTER=${audit_rules[$PARAM]} #Fetching the rule's counter which indicates the number of child rules for the current rule
                            [[ $DEBUG -eq 1 ]] && echo "RULE_CHAIN:: Counter = $COUNTER"
    PARAM=${PARAM%,*}	        # Substring from the begging to the comma (,) to get the parameter name without the index
                            [[ $DEBUG -eq 1 ]] && echo "RULE_CHAIN: Subtracted Key Name is ($PARAM)"
    					    #Fetching the Used Acceptance for the current rule from the profile file.
	check-pf ${PARAM} check     #Fetching the Used Acceptance for the current rule from the profile file.
    USER_CHECK_ACCEPTENCE=$?


	check-pf ${PARAM} action
	USER_ACTION_ACCEPTENCE=$?
	

                            [[ $DEBUG -eq 1 ]] && echo "RULE_CHAIN: User Acceptance = $USER_CHECK_ACCEPTENCE"
							[[ $DEBUG -eq 1 ]] && echo "RULE_CHAIN: User Action Acceptance = $USER_ACTION_ACCEPTENCE"



    #Checking whether the rule is accepted, if it not just print a message and continue;                         
    if [[ $USER_CHECK_ACCEPTENCE == 0 ]] ; then echo "$SCRIPT_NAME: ($PARAM) : RULE NOT ACCEPTED : Skipping." ; continue ; fi
                           
                            [[ $DEBUG -eq 1  ]] && echo "RULE_CHAIN: Checking Rule Accepted ($PARAM)"


    #PARAMETERS_LIST=$( echo $PROFILE |  jq -r ".firewall.$PARAM.parameters" ) #Fetching Rule's Parameters from the profile file.

    PARAMETERS_LIST=null
                            [[ $DEBUG -eq 1  ]] && echo "lOCAL PARAMETER LIST IS (${PARAMETERS_LIST})"
    

    #Adding the parameters to the rules before checking them. 
    FINAL_RULE=$( ReplaceParameters $COUNTER $PARAM "${PARAMETERS_LIST}" )

                            [[ $DEBUG -eq 1  ]] && echo -e "RULE_CHAIN: Rules set are: ($FINAL_RULE)"
                            [[ $DEBUG -eq 1  ]] && echo -e "RULE_CHAIN: Checking Rule .. \n"


    #Fetching the Description from the rules dictionary ;
    DESCRIPTION=${audit_rules["$PARAM,d"]}
                            [[ $DEBUG -eq 1  ]] && echo "RULE_CHAIN: Description is ($DESCRIPTION)"


    #Pipping the rules to the check_rule function to be checked
	
	echo -e $FINAL_RULE | check_rule
      
	                            
done

[[ $GENERAL_ACTIONS_ACCEPTENCE -eq 1 ]] && echo "$AUDITD_ACTIONS_FILE" >> $ACTIONS_FILE


echo -e "\nAuditd Hardening script has finished...\n"


















