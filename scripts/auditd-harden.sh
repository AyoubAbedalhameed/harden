#!/bin/bash

#This script is a part of harden project, it will be used for hardening auditd with recommended rules.

echo "auditd script is running .. "

STATUS_FILE=$1
MESSAGES_FILE=$2
ACTIONS_FILE=$3

#The MD5 Digest from the recommended rules file (Removed Spaces). 
RecommendedRulesDigest="0acd49f5b6d87997c6552e19f60da91d"


#Checking the existence and status of auditd. 



systemctl status auditd > /dev/null
status=$?


if [[ $status -eq 4 ]]  ; then 
echo "$0:RULE-UNMATCHED: auditd is not installed">> $MESSAGES_FILE 
echo "auditd.installed 1" >> $STATUS_FILE 
Case=1

elif [[ $status -eq 0  || $status -eq 3 ]] ; then
echo "$0:RULE-MATCHED: auditd is installed" >> $MESSAGES_FILE 
echo "auditd.installed 0" >> $STATUS_FILE 
CurrentRulesFileDigest=$(cat /etc/audit/rules.d/audit.rules | tr -d " \t\n\r" | md5sum)
if [[ $CurrentRulesFileDigest == $RecommendedRulesDigest ]]; then 
echo "$0:RULE-MATCHED: Recommedned auditd rules are used.">> $MESSAGES_FILE 
echo "auditd.recommended-rules 0" >> $STATUS_FILE 
case=0
else
echo "$0:RULE-UNMATCHED: Recommedned auditd rules not used.">> $MESSAGES_FILE 
echo "auditd.recommended-rules 1" >> $STATUS_FILE 
case=2
fi

else  
echo "Checking the status of auditd faild: UNKNOWN STATUS"
exit 1
fi


[ $case -nq 0] && echo "auditd.action $case" >> $ACTIONS_FILE
exit 0 












