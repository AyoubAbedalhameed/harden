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

[[ $(_check_profile_file_function file_permission check) == 0 ]] && exit

PARAMETER_FILE="$MAIN_DIR/resources/rolefile.txt"
echo "check permission start ..."

while read -r line; do
	service=$(echo $line | awk '{print $1;}')
	perm=$(echo $line | awk '{print $2;}')
	user=$(echo $line | awk '{print $3;}')
	group=$(echo $line | awk '{print $4;}')
	file=$(echo $line | awk '{print $5;}')
	message=${line#*=+@}

	[[ $(_check_profile_file_function file_permission permissions check) == 1 ]] && find $file -perm $perm >& /dev/null && {
		echo "File_Permission permissions -[$service]:'$file' file permissions user/owner group is not as recommended ($perm). $message" >> "$MESSAGES_FILE"
	}

	[[ $(_check_profile_file_function file_permission owner_user check) == 1 ]] && find $file -user $user >& /dev/null && {
		echo "File_Permission Owner_User -[$service]:'$file' file owner user is not as recommended ($user). $message" >> "$MESSAGES_FILE"
	}

	[[ $(_check_profile_file_function file_permission owner_group check) == 1 ]] && find $file -group $group >& /dev/null && {
		echo "File_Permission Owner_Group -[$service]:'$file' file owner group is not as recommended ($group). $message" >> "$MESSAGES_FILE"
	}
done < "$PARAMETER_FILE"

echo "check permission finished..."
