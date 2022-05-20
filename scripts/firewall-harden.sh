#!/usr/bin/env bash

#Prevent overwriting files
set -C

#Importing firewall rules: 
source iptables-rules.rc 



#Fetching Script run time. 
RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time


echo "$0:$RUNTIME_DATE   script is running .. "

#Getting User's Options:
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
		
		-d|--debug)
			DEBUG=1 
			shift 1
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



# Preparing not initialized Filesystem Variables :
MAIN_DIR=${MAIN_DIR:="/usr/share/harden"}
PROFILE_FILE=${PROFILE_FILE:="/etc/harden/default.profile"}	# Use Default User Choice Profile File, 
								# if not set by a positional parameter (command line argument)
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/$RUNTIME_DATE.status"}	# Currently used status file
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file

SOURCE_FILE="$MAIN_DIR/config/iptables-rules.rc"
FIREWALL_ACTIONS_FILE="$MAIN_DIR/config/$RUNTIME_DATE-firewall-actions.sh"
 
# Preparing not initialized other Variables:
DEBUG=${DEBUG:=0}





#Extracting script profile from the systemm profile file. 
PROFILE=$(jq '.[] | select(.name=="firewall")' $PROFILE_FILE)	# Save our object from the array



#Cheking the Acceptance of firewall-hardening Checks: 
if [[ `echo $PROFILE | jq '.firewall.check' ` -ne 1 ]] ; then 
echo "$RUNTIME_DATE:$0:Terminates, Checking is now allowed"
exit
fi




#Cheking the Acceptance of firewall-hardening Actions: 
if [[ `echo $PROFILE | jq '.firewall.action'` -ne 1 ]] ; then 
echo "#!/usr/bin/env bash" >> $FIREWALL_ACTIONS_FILE ; fi




#Functions Definitions: 

## To query a value from JSON profile file
check-pf()  { return $(echo $PROFILE | jq ".firewall.$1.$2");  }

## ReplaceParameters() function, used to add the user parameters to the iptables rule.
 ReplaceParameters () 
{ #Usage: ReplaceParameter <RulesCount> <RuleName> <ParametersList> 


	for (( i=1; i<=$1 ; i++ )) ; do 	  #
  
    	local Temp="${FW_Rules["$2,$i"]}" #Fetching the current tule from the rules dictionary. 
    	[[ "$3" == "null" ]]  && echo "$Temp\n" && continue ; #If the parameters list is null, replace nothing.
    	local PARAMETERS_COUNTER=0		 	 #Used as index do define the current parameter number in the loop.
   		 for PARAMETER in $3 ; do

        	Temp=$( echo $Temp | sed "s/@${PARAMETERS_COUNTER}/${PARAMETER}/g" )  #Replacing all occurrences for the current parameter in the current string. 
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
	                    [[ $DEBUG -eq 1 ]] && echo -e "Local Rules are ($RULES)"

	while read RULE ; do
    	                [[ $DEBUG -eq 1 ]] && echo "The rule is $RULE"
    	iptables -C `echo $RULE`
    	RULE_STATUS=$?
    	                [[ $DEBUG -eq 1 ]] && echo "Rule status $RULE_STATUS"
    	[[ $RULE_STATUS -ne 0 ]] && return 0
    done <<< "$RULES"
    
	return 1
}


#Cheking Firewall Services: 

Flag=1 


#Checking Firewalld Service:  
echo "$RUNTIME_DATE:$0:Checking firewalld service status" 
systemctl status firewalld
firewalld_status=$?

if [[ ! $firewalld_status -eq  4 ]] ; then 
firewalld_enabled=$(systemctl is-enabled firewalld) 
firewalld_active=$(systemctl is-active firewalld) ; Flag=$? 
firewalld_installed=1
else firewalld_enabled="disabled" ; firewalld_active="inactive" ; firewalld_installed=0; fi 


#Cheking Iptables Service:  
echo "$RUNTIME_DATE:$0:Checking firewalld service status" 
systemctl status iptables 
iptables_status=$? 

if [[ ! $iptables_status -eq  4 ]] ; then 
iptables_enabled=$(systemctl is-enabled iptables) ; echo $iptables_enabled
iptables_active=$(systemctl is-active iptables); Flag=$?
iptables_installed=1
else iptables_enabled="disabled" ; iptables_active="inactive" ; iptables_installed=0 ; fi 


echo "$0.firewalld.installed $firewalld_installed" >> $STATUS_FILE
echo "$0.firewalld.enabled $firewalld_enabled" >> $STATUS_FILE 
echo "$0.firewalld.active $firewalld_active " >> $STATUS_FILE

echo "$0.iptables.installed $iptables_installed" >> $STATUS_FILE
echo "$0.iptables.enabled $iptables_enabled" >> $STATUS_FILE
echo "$0.iptabled.active $iptables_active" >> $STATUS_FILE




if [[ iptables_installed -eq 0 && firewalld_installed -eq 0 ]] 
then echo "$0:$RUNTIME_DATE No Firewall Service Installed on this machine, at least one firewall service should be running" >> $MESSAGES_FILE
NoFireWall=0 ; fi


[[ $Flag -ne 0 ]] && echo "$0:$RUNTIME_DATE Firewall services are not enabled on this machine, you should enable one firewall service at least on your system" >> $MESSAGES_FILE 


if [[ iptables_installed -ne 1 ]] ; then 

    echo "$0:$RUNTIME_DATE: iptables is not installed, iptables rules checking will be skipped"
    exit
fi





#Iterating over the keys of the iptables-rules (Rules Names): 
for PARAM in $( echo "${!FW_Rules[@]}" | sed 's/[a-z\0-9\.\_\-]*,[d\1-9]//g' ); do
                
                            [[ $DEBUG -eq 1 ]] && echo "+++++++++++++++++++++++++"
                            [[ $DEBUG -eq 1 ]] && echo "Full-PARAM= ($PARAM)"
                            
    COUNTER=${FW_Rules[$PARAM]} #Fetching the rule's counter which indicates the number of child rules for the current rule
                            [[ $DEBUG -eq 1 ]] && echo "Counter = $COUNTER"
    PARAM=${PARAM%,*}	        # Substring from the begging to the comma (,) to get the parameter name without the index
                            [[ $DEBUG -eq 1 ]] && echo "PARAM= ($PARAM)"
    check-pf ${PARAM} check     #Fetching the Used Acceptance for the current rule from the profile file.
    USER_ACCEPTANCE=$?

                            [[ $DEBUG -eq 1 ]] && echo "User Acceptance = $USER_ACCEPTANCE"

    #Checking whether the rule is accepted, if it not just print a message and continue;                         
    if [[ $USER_ACCEPTANCE == 0 ]] ; then echo "$0:$RUNTIME_DATE:($PARAM):RuleNotAccepted:Skipping." ; continue ; fi
                           
                            [[ $DEBUG -eq 1  ]] && echo "Rule Accepted ($PARAM)"


    PARAMETERS_LIST=$( echo $PROFILE |  jq -r ".firewall.$PARAM.parameters" ) #Fetching Rule's Parameters from the profile file.

                            [[ $DEBUG -eq 1  ]] && echo "lOCAL PARAMETER LIST IS (${PARAMETERS_LIST})"


    #Adding the parameters to the rules before checking them. 
    FINAL_RULE=$(ReplaceParameters $COUNTER $PARAM "${PARAMETERS_LIST}" )

                            [[ $DEBUG -eq 1  ]] && echo -e "Finel Rule: ($FINAL_RULE)"
                            [[ $DEBUG -eq 1  ]] && echo -e "\nChecking Rule .. \n"

    #Pipping the rules to the check_rule function to be checked
    echo -e $FINAL_RULE | check_rule 
    RULE_STATUS=$?

                            [[ $DEBUG -eq 1  ]] && echo "-----------------------------"

    #Fetching the Description from the rules dictionary ;
    DESCRIPTION=${FW_Rules["$PARAM,d"]}
                            [[ $DEBUG -eq 1  ]] && echo "Description is ($DESCRIPTION)"

    if [[ RULE_STATUS -ne 1 ]] ; then echo "$0:$RUNTIME_DATE:$PARAM:RULE_NOT:MATCHED:$DESCRIPTION" >> $MESSAGES_FILE ; fi
done

