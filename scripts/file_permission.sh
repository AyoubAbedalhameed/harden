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

while read -r line; do
	service=$(echo $line | awk '{print $1;}')
	recom_par=$(echo $line | awk '{print $2;}')
	perm=$(echo $line | awk '{print $3;}')
	user=$(echo $line | awk '{print $4;}')
	group=$(echo $line | awk '{print $5;}')
	file=$(echo $line | awk '{print $6;}')
	message=${line#*=+@}
#	message=$(echo $line |awk '{for (i=6;i<NF;i++) print $i " "; print $NF}')

	[[ $(_check_profile_file_function file_permission permissions check) != 1 ]] && find $file -perm $perm && {
		echo "File_Permission permissions -[$service]:'$file' file permissions user/owner group is not as recommended ($perm). $message" >> "$MESSAGES_FILE"
	}

	[[ $(_check_profile_file_function file_permission owner-user check) != 1 ]] && find $file -user $user && {
		echo "File_Permission owner-uer -[$service]:'$file' file owner user is not as recommended ($user). $message" >> "$MESSAGES_FILE"
	}

	[[ $(_check_profile_file_function file_permission owner-group check) != 1 ]] && find $file -group $group && {
		echo "File_Permission owner-group -[$service]:'$file' file owner group is not as recommended ($group). $message" >> "$MESSAGES_FILE"
	}
done < rolefile.txt

echo "check permission finished..."
