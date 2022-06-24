#!/usr/bin/env bash
# Written By: mohammed ananzeh (mwananzeh99@gmail.com)

# user and group hardening through checking and warning with
# recommended solutions 

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
user and group Hardening is starting up as pid=$$ at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

PARAMETER_FILE="/home/mohammeananzeh/Desktop/services.txt"
echo "user and group hardening start ..."
echo "////////////////////////////////"

cat $PARAMETER_FILE | while read line || [[ -n $line ]];
do
 service=$(echo $line | awk '{print $1;}')
 recom_par=$(echo $line | awk '{print $2;}')
 recom_val1=$(echo $line | awk '{print $3;}')
# recom_val2=$(echo $line | awk '{print $4;}')
 message=$(echo $line |awk '{for (i=4;i<NF;i++) print $i " "; print $NF}')

#//////////////////////////////////////////
#check from all users account have passowrd

 password_current_val=$(cat /etc/shadow |awk -F: '($2 == "" ) {print $1}')
 if [[ $service == "user_password" ]] && [[ ! -z $password_current_val ]]
    then echo $message ,but {$password_current_val } user dont have one lock it until implement a password  >> "$MESSAGES_FILE"
     #echo "use the following command to lock the user unti check from it: #passwd -l <username>"   also you can use the following command to put a password for the user #passwd
 fi
#//////////////////////////////////////////
#check the UID value for root user


  UID_current_val=$(cat /etc/passwd | awk -F: '($3 == 0) {print $1}')
  if [[ $service == "UID_harden" ]] && [[ $UID_current_val != $recom_val1 ]]
  then
    echo $message , the current acount is {$UID_current_val} but the recommanded value is {$recom_val1} >> "$MESSAGES_FILE"
 fi
#//////////////////////////////
#check if there any netrc files

 netrc_current_val=$(for dir in `cat /etc/passwd | awk -F: '{ print $6  }'`; do
                if [ ! -h "$dir/.netrc" -a -f "$dir/.netrc" ]; then
                   echo ".netrc file $dir/.netrc exist"
               # else current_val=null
                fi
              done
              )
 if [[ $service == "FTP_service" ]] && [[ $netrc_current_val -ne null ]]
   then  echo $message, the $service return with files $netrc_current_val {not null}  but the recommended value is {$recom_val1} or {$recom_val2} >> "$MESSAGES_FILE"
    #echo "to remove these files use the following command:"
    # ./file
    #{for dir in `cat /etc/passwd | awk -F: '{ print $6  }'`; 
    #            if [ ! -h "$dir/.netrc" -a -f "$dir/.netrc" ]; then
    #               rm -rf $dir/.netrc
    #           # else current_val=null
    #            fi
    # }>> "$ACTIONS_FILE"           

 fi
#/////////////////////////////////////////
#check from forward files
 forward_current_val=$(for dir in `cat /etc/passwd | awk -F: '{print $6}'`; do
                        if [ ! -h "$dir/.forward" -a -f "$dir/.forward" ]; then
                            echo ".forward file $dir/.forward exists"
                        fi
                        done     
                        )
 if [[ $service == "forward_file" ]] && [[ $forward_current_val -ne null ]]
  then  echo $message ,the $service return with files $forward_current_val {not null} but the recommanded value is {$recom_val1} or {$recom_val2} >> "$MESSAGES_FILE"
        echo "///////////////////////////////"
        #echo "to remove these return files use the following file"
        #./file
        #{for dir in `cat /etc/passwd | awk -F: '{print $6}'`; do
        #                if [ ! -h "$dir/.forward" -a -f "$dir/.forward" ]; then
        #                    rm -rf $dir/.forward 
        #                fi
        # } >> "$ACTIONS_FILE"               done
 fi
#////////////////////////////////////////////////
#check from rhost files
 rhost_current_val=$(for dir in `cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)'|awk -F: '($7 != "/usr/sbin/nologin") {print $6}'`;do
                        for file in $dir/.rhost; do
                            if [ ! -h "$file" -a -f "$file" ]; then
                                echo ".rhost file in $dir"
                            fi
                        done
                    done    
                    )
 if [[ $service == "rhost_file" ]] && [[ $rhost_current_val -ne null ]]
    then    echo $message,the $service return with files $rhost_current_val {not null} but the recommanded value is {$recom_val1} or {$recom_val2} >> "$MESSAGES_FILE"
            echo "///////////////////////////////"
        #echo "to remove these return files use the following file"
        #./file
        #{for dir in `cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)'|awk -F: '($7 != "/usr/sbin/nologin") {print $6}'`;do
        #                for file in $dir/.rhost; do
        #                    if [ ! -h "$file" -a -f "$file" ]; then
        #                        rm -rf $dir/.rhost"
        #                    fi
        #                done
        #            done} >> "$ACTIONS_FILE"
 fi
#/////////////////////////////////////////////
#check if there duplicate in users ID
 Duplicate_UID=$(cat /etc/passwd |cut -f3 -d":" | sort -n |uniq -c |while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
    users=`awk -F: '($3 == n) {print $1}' n=$2 /etc/passwd | xargs`
    echo "duplicate uid ($2): ${users}"
 fi
 done)
 if [[ $service == "duplicate_uid" ]] && [[ $Duplicate_UID -ne null ]]
    then echo $message, there are these duplicated user IDs $Duplicate_UID {not null} but it recommanded to be {$recom_val1} or {$recom_val2} >> "$MESSAGES_FILE"
         #echo "the (useradd) programm will not let you create a diplicate User ID(UID),it is possible for an administrator to manually edit the /etc/passwd file and change the UID field" >> "$ACTIONS_FILE" 
 fi
#/////////////////////////////////////////
#check if there duplicate in group ID
 Duplicate_GID=$(cat /etc/group |cut -f3 -d":" | sort -n |uniq -c |while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
    groups=`awk -F: '($3 == n) {print $1}' n=$2 /etc/group | xargs`
    echo "duplicate GID ($2): ${groups}"
 fi
 done)
 if [[ $service == "duplicate_gid" ]] && [[ $Duplicate_GID -ne null ]]
    then echo $message, there are these duplicated group IDs $Duplicate_GID {not null} but it recommanded to be {$recom_val1} or {$recom_val2} >> "$MESSAGES_FILE"
        #echo "the (groupadd) programm will not let you create a diplicate Gropu ID(GID),it is possible for an administrator to manually edit the /etc/group file and change the GID field" >> "$ACTIONS_FILE"
 fi
#/////////////////////////////////////////
#check no duplicate in username
username_currentval=$(cat /etc/passwd |cut -f1 -d":" |sort -n| uniq -c|while read x ; do
                       [ -z "${x}" ] && break
                       set - $x
                       if [ $1 -gt 1 ]; then
                           uids=`awk -F: '($1 == n) {print $3}' n=$2 /etc/passwd | xargs` 
                           echo "DUplicate Username ($2): ${uids}"
                       fi
                    done
) 
if [[ $service == "duplicated_username" ]] && [[ ! -z $username_currentval ]]
    then echo $message,but there a duplicate in it which is not recommended. >> "$MESSAGES_FILE"
        #echo "useradd programm will not you create a duplicat username,it is possible for an adminstrator to manually edit the /etc/passwd file and chang it. ">> "$ACTIONS_FILE"

fi
#/////////////////////////////////////////
#check no duplicate in group name
groupname_currentval=$(cat /etc/group |cut -f1 -d":" |sort -n| uniq -c|while read x ; do
                       [ -z "${x}" ] && break
                       set - $x
                       if [ $1 -gt 1 ]; then
                           gids=`awk -F: '($1 == n) {print $3}' n=$2 /etc/passwd | xargs` 
                           echo "DUplicate Groupname ($2): ${gids}"
                       fi
                    done
) 
if [[ $service == "duplicated_groupname" ]] && [[ ! -z $groupname_currentval ]]
    then echo $message,but there a duplicate in group name it which is not recommended. >> "$MESSAGES_FILE"
        #echo "groupadd programm will not you create a duplicate groupname,it is possible for an adminstrator to manually edit the /etc/group file and chang it. ">> "$ACTIONS_FILE"

fi

#/////////////////////////////////////////////
#check all group in /etc/passwd exist in /etc/group
 
exist_file=$(for i in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
                grep -q -P "^.*?:[^:]*:$i:" /etc/group 
                    if [ $? -ne 0 ]; then 
                        echo "Group $i is referenced by /etc/passwd but does not exist in /etc/group" 
                    fi 
            done
            )
if [[ $service == "group_passwd_file" ]] && [[ ! -z $exist_file ]]
    then echo $message,but there this GID in /etc/passwd but does not exist in /etc/group >> "$MESSAGES_FILE"
    #echo Analyze the output of the Audit step above and perform the appropriate action to correct any discrepancies found.>> "$ACTIONS_FILE"
fi 

#/////////////////////////////////////////////
#check no unowned or ungroup files and directory

dir_currentval=$(find / -path /proc -prune -o -path /run -prune -o -path /tmp -prune -o -path /sys -prune -o -nouser -nogroup)

if [[ $service == "dir_file_unowned" ]] && [[ ! -z $dir_currentval ]] 
    then
  echo $message, but there these {$dir_currentval} file or directory are unowned check them >> "$MESSAGES_FILE"
  #echo Locate files that are owned by users or groups not listed in the system configuration files, and reset the ownership of these files to some active user on the system as appropriate.  >> "$ACTIONS_FILE" 
fi
#////////////////////////////////////////////
#check there is no "+" in passwd file 
 
 passwd_current_val=$(grep '^+:' /etc/passwd) 
 if [[ $service == "legacy_passwd" ]] && [[ $passwd_current_val -ne null ]]
    then echo $message,its not recommanded to be a "'+'" in passwd file. >> "$MESSAGES_FILE"   
    #echo use the folowing command to remove it :#sed -i '/+/d' passwd >> "$ACTIONS_FILE"
 fi
#////////////////////////////////////////////
#check there is no "+" in group file
 
 group_current_val=$(grep '^+:' /etc/group) 
 if [[ $service == "legacy_group" ]] && [[ $group_current_val -ne null ]]
    then echo $message,its not recommanded to be a "'+'" in group file. >> "$MESSAGES_FILE"  
    #echo use the folowing command to remove it :#sed -i '/+/d' group >> "$ACTIONS_FILE"
 fi
#////////////////////////////////////////////
#check there is no "+" in shadow file
 
 shadow_current_val=$(grep '^+:' /etc/shadow) 
 if [[ $service == "legacy_shadow" ]] && [[ $shadow_current_val -ne null ]]
    then echo $message,its not recommanded to be a "'+'" in shadow file. >> "$MESSAGES_FILE"    
    #echo use the folowing command to remove it :#sed -i '/+/d' shadow >> "$ACTIONS_FILE"
 fi 

#/////////////////////////////////////////
#check that access to su command is restricted
su_currentval=$(grep -v ^# /etc/pam.d/su |grep pam_wheel.so)
if [[ $service == "su_restricted" ]] && [[ ! -z $su_currentval ]]
  then echo $message >> "$MESSAGES_FILE"
       #echo "uncomment the following text in /etc/pam.d/su file to becom restricted">> "$ACTIONS_FILE"
       #echo auth required pam_wheel.so use_uid >> "$ACTIONS_FILE"
       
fi  
done


echo "user and group hardening finished..."