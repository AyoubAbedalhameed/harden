#!/usr/bin/env bash
# Written By: mohammed ananzeh (mwananzeh99@gmail.com)

# file permissions hardening through checking and warning with
# recommended solutions and permission

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
permission Hardening is starting up as pid=$$ at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"


PARAMETER_FILE="$MAIN_DIR/resources/rolefile.txt"
echo "check permission start ..."
echo "/////////////////////////////////"
sleep 3
cat $PARAMETER_FILE | while read line || [[ -n $line ]];
do
 service=$(echo $line | awk '{print $1;}')
 recom_par=$(echo $line | awk '{print $2;}')
 recom_val1=$(echo $line | awk '{print $3;}')
 recom_val2=$(echo $line | awk '{print $4;}')
 recom_val3=$(echo $line | awk '{print $5;}')
 message=$(echo $line |awk '{for (i=6;i<NF;i++) print $i " "; print $NF}')
 
#///////////////////////////////////////////
#check the status for passwd file and compare it with recommanded    
 
 permission_passwd=$(find /etc/passwd -perm 644 -user root -group root)
 if [[ $service == "passwd_file" ]] && [[ -z $permission_passwd ]]
    then echo "file-permission[$recom_par]:(the current permission nad owners for passwd file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
  #echo "to change the permission and owner for file use :" #chmod 644 /etc/passwd #chown root:root /etc/passwd >> "$ACTIONS_FILE"
 fi


#//////////////////////////////////////////

  
permission_group=$(find /etc/group -perm 644 -user root -group root)
 if [[ $service == "group_file" ]] && [[ -z $permission_group ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for group file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
  #echo "to change the permission and owner for file use :" #chmod 644 /etc/group #chown root:root /etc/group >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////
#check the status for shadow file and compare it with recommanded    
 
permission_shadow=$(find /etc/shadow -perm 600 -user root -group root)
 if [[ $service == "shadow_file" ]] && [[ -z $permission_shadow ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for shadow file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
  #echo "to change the permission and owner for file use :" #chmod 600 /etc/shadow #chown root:root /etc/shadow >> "$ACTIONS_FILE"
 fi


#//////////////////////////////////////////
#check the status for gshadow file and compare it with recommanded    
 
permission_gshadow=$(find /etc/gshadow -perm 600 -user root -group root)
 if [[ $service == "gshadow_file" ]] && [[ -z $permission_gshadow ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for gshadow file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/gshadow #chown root:root /etc/gshadow >> "$ACTIONS_FILE"
 fi

#///////////////////////////////////////////
#check the status for passwd- file and compare it with recommanded    
  
permission_passwdb=$(find /etc/passwd- -perm 600 -user root -group root)
 if [[ $service == "passwdb_file" ]] && [[ -z $permission_passwdb ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for passwd- file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/passwd- #chown root:root /etc/passwd- >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////
#check the status for group- file 
permission_groupb=$(find /etc/group- -perm 600 -user root -group root)
 if [[ $service == "groupb_file" ]] && [[ -z $permission_groupb ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for group- file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/group- #chown root:root /etc/group- >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////
#check the status for shadow file and compare it with recommanded    
  
permission_shadowb=$(find /etc/shadow- -perm 600 -user root -group root)
 if [[ $service == "shadowb_file" ]] && [[ -z $permission_shadowb ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for shadow- file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/shadow- #chown root:root /etc/shadow- >> "$ACTIONS_FILE"
 fi



#//////////////////////////////////////////
#check the status for gshadow- file      
 
permission_gshadowb=$(find /etc/gshadow- -perm 600 -user root -group root)
 if [[ $service == "gshadowb_file" ]] && [[ -z $permission_gshadowb ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for gshadow- file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/gshadow- #chown root:root /etc/gshadow- >> "$ACTIONS_FILE"
 fi





#//////////////////////////////////////////////////////////////
#check the permission on /boot/default/grub.cfg file
 
permission_bootgrub=$(find /boot/grub2/grub.cfg -perm 600 -user root -group root)
 if [[ $service == "bootgrub_file" ]] && [[ -z $permission_bootgrub ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for grub.cfg file not as recommended). $message ">> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /boot/grub2/grub.cfg #chown root:root /boot/grub2/grub.cfg >> "$ACTIONS_FILE"
 fi
#////////////////////////////////
#check the permission value for /etc/grub2.cfg
 
permission_etcgrub=$(find /etc/grub2.cfg -perm 600 -user root -group root)
 if [[ $service == "etcgrub_file" ]] && [[ -z $permission_etcgrub ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for grub.cfg file not as recommended). $message ">> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/grub2.cfg  #chown root:root /etc/grub2.cfg  >> "$ACTIONS_FILE"
 fi



#////////////////////////////////////////////////////
  
permission_defaultgrub=$(find /etc/default/grub -perm 644 -user root -group root)
 if [[ $service == "etcgrdefaultgrub_fileub_file" ]] && [[ -z $permission_etcgrub ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for grub file not as recommended). $message ">> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 644 /etc/default/grub  #chown root:root /etc/default/grub >> "$ACTIONS_FILE"
 fi

#/////////////////////////////////
#check anancrontab file permission
  
permission_anacrontab=$(find /etc/anacrontab -perm 600 -user root -group root)
 if [[ $service == "anacrontab_file" ]] && [[ -z $permission_anacrontab ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for anacrontab file not as recommended). $message ">> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/anacrontab  #chown root:root /etc/anacrontab >> "$ACTIONS_FILE" 
 fi

#/////////////////////////////////////////
#check the crontb file permission 
  
permission_crontab=$(find /etc/crontab -perm 600 -user root -group root)
 if [[ $service == "crontab_file" ]] && [[ -z $permission_crontab ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for anacrontab file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/crontab  #chown root:root /etc/crontab >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////////
#check /etc/cron.d directory
  
permission_crontabd=$(find /etc/cron.d/ -type d -perm 600 -user root -group root)
 if [[ $service == "cron.d_dir" ]] && [[ -z $permission_crontabd ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for cron.d directory not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/cron.d/  #chown root:root /etc/cron.d/ >> "$ACTIONS_FILE"
 fi



#//////////////////////////////////////////////
#check /etc/cron.hourly directory
  
permission_cronhourly=$(find /etc/cron.hourly/ -type d -perm 600 -user root -group root)
 if [[ $service == "cron.hourly_dir" ]] && [[ -z $permission_cronhourly ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for cron.d directory not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/cron.hourly/  #chown root:root /etc/cron.hourly/ >> "$ACTIONS_FILE"
 fi



#//////////////////////////////////////////////
#check /etc/cron.daily directory
  
permission_crondaily=$(find /etc/cron.daily/ -type d -perm 600 -user root -group root)
 if [[ $service == "cron.daily_dir" ]] && [[ -z $permission_crondaily ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for cron.daily directory not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/cron.daily/  #chown root:root /etc/cron.daily/ >> "$ACTIONS_FILE"
 fi
#//////////////////////////////////////////////
#check /etc/cron.weekly directory
  
permission_cronweekly=$(find /etc/cron.weekly/ -type d -perm 600 -user root -group root)
 if [[ $service == "cron.weekly_dir" ]] && [[ -z $permission_cronweekly ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for cron.weekly directory not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/cron.weekly/  #chown root:root /etc/cron.weekly/ >> "$ACTIONS_FILE"
 fi



#//////////////////////////////////////////////
#check /etc/cron.monthly directory
  
permission_cronmonthly=$(find /etc/cron.monthly/ -type d -perm 600 -user root -group root)
 if [[ $service == "cron.monthly_dir" ]] && [[ -z $permission_cronmonthly ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for cron.monthly directory not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 600 /etc/cron.monthly/  #chown root:root /etc/cron.monthly/ >> "$ACTIONS_FILE"
 fi 
#//////////////////////////////////////////////////
#check the host.conf file
 
permission_hostconf=$(find /etc/host.conf -perm 644 -user root -group root)
 if [[ $service == "host.conf_file" ]] && [[ -z $permission_hostconf ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for host.conf file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 644 /etc/host.conf  #chown root:root /etc/host.conf >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////////////
#check the hosts file
  
permission_hosts=$(find /etc/hosts -perm 644 -user root -group root)
 if [[ $service == "hosts_file" ]] && [[ -z $permission_hosts ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for hosts file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 644 /etc/hosts  #chown root:root /etc/hosts >> "$ACTIONS_FILE"
 fi

#//////////////////////////////////////////////////
#check the hostname file
  
permission_hostname=$(find /etc/hostname -perm 644 -user root -group root)
 if [[ $service == "hostname_file" ]] && [[ -z $permission_hostname ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for hosts file not as recommended). $message" >> "$MESSAGES_FILE"
    echo "///////////////////////////////////////"
 #echo "to change the permission and owner for file use :" #chmod 644 /etc/hostname  #chown root:root /etc/hostname >> "$ACTIONS_FILE"
 fi
#///////////////////////////////////////
#check from sshd_config permission

permission_sshd_config=$(find /etc/ssh/sshd_config -perm 600 -user root -group root)
 if [[ $service == "sshd_config_file" ]] && [[ -z $permission_sshd_config ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for sshd_config file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 600 /etc/ssh/sshd_config  #chown root:root /etc/ssh/sshd_config >> "$ACTIONS_FILE"
    echo "/////////////////////////////////////////"
 fi
#//////////////////////////////////////////////
#check the permission for resolved.conf

permission_resolved=$(find /etc/systemd/resolved.conf -perm 600 -user root -group root)
 if [[ $service == "resolved.conf_file" ]] && [[ -z $permission_resolved ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for sshd_config file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod ox-rwx /etc/systemd/resolved.conf  #chown root:root /etc/systemd/resolved.conf >> "$ACTIONS_FILE"
    echo "//////////////////////////////////////////"
 fi

#//////////////////////////////////////////////
#check the permission for exports

permission_resolved=$(find /etc/exports -perm 644 -user root -group root)
 if [[ $service == "exports_file" ]] && [[ -z $permission_resolved ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for exports file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 644 /etc/exports  #chown root:root /etc/exports >> "$ACTIONS_FILE"
    echo "///////////////////////////////////////"
 fi
#//////////////////////////////////////////////
#check the permission for sudoers file

permission_sudoers=$(find /etc/sudoers -perm 440 -user root -group root)
 if [[ $service == "sudoers_file" ]] && [[ -z $permission_sudoers ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for sudoers file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 440 /etc/sudoers  #chown root:root /etc/sudoers >> "$ACTIONS_FILE"
    echo "///////////////////////////////////////"
 fi


#//////////////////////////////////////////////
#check the permission for /var/spool/cron

permission_spoolcron=$(find /var/spool/cron -type d -perm 600 -user root -group root)
 if [[ $service == "cronspool_file" ]] && [[ -z $permission_spoolcron ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for /var/spool/cron file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 600 /var/spool/cron >> "$ACTIONS_FILE"
    echo "//////////////////////////////////////////"
 fi
#//////////////////////////////////////////////
#check the permission for /var/run/utmp

permission_runutmp=$(find /var/run/utmp -perm 664 -user root -group utmp)
 if [[ $service == "varrun_utmp_file" ]] && [[ -z $permission_runutmp ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for /var/run/utmp file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 664 /var/run/utmp >> "$ACTIONS_FILE"
    exho "////////////////////////////////////"
 fi

#//////////////////////////////////////////////
#check the permission for /var/run/utmp

permission_runutmp=$(find /var/log/wtmp -perm 664 -user root -group utmp)
 if [[ $service == "varlog_wtmp_file" ]] && [[ -z $permission_runutmp ]]
    then echo "file-permission[$recom_par]:(the current permission or owners for /var/log/wtmp file not as recommended). $message" >> "$MESSAGES_FILE"
    #echo "to change the permission and owner for file use :" #chmod 664 /var/log/wtmp #chown root:utmp /var/log/wtmp >> "$ACTIONS_FILE"
    echo "////////////////////////////////////////////"
 fi


done

echo "check permission finished..."






