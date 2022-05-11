#!/usr/bin/env bash
#This script is a part of harden project, it will be used for hardening linux firewall with recommended rules.

#Prevent overwriting files
set -C

#Fetching run time. 
RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time

echo "$RUNTIME_DATE:$0   script is running .. "

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