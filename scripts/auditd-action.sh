#!/usr/bin/bash
#Message=""

echo "$(date) auditd-action is running"
Mode=$1 
auditdPackage="audit.x86_64"

if [ $Mode -eq 1 ] ; then
echo "$0: Installing auditd package" && yum install $auditdPackag && echo "$0: $auditdPackage Instaled Succefully" \
|| echo "$0: $auditdPackage Installation Failed." && exit 1 
fi


[ -f /usr/share/harden/resources/audit.rules ] && mv -f /usr/share/harden/resources/auditd.rules /etc/audit/rules.d \
|| echo "$0: /usr/share/harden/resources/audit.rules NOT EXIST" && exit 1 

echo "$0: Recommended auditd rules have been employed succsufully."
echo "$0: Restarting auditd .."
service auditd restart 
exit 0

