#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# Different recommended file system hardening options and configuration

usage() {   echo "Usage: $0 -md/--main-directory [main directory] -pf/--profile-file [profile file] \
-st/--status-file [status file] -mf/--messages-file [messages file] -af/--actions-file [actions file]"; }

RUNTIME_DATE=$(date +%F_%H:%M:%S)	# Runtime date and time

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

MAIN_DIR=${MAIN_DIR:="/usr/share/harden"}
PROFILE_FILE=${PROFILE_FILE:="/etc/harden/default.profile"}	# Use Default User Choice Profile File,
										# if not set by a positional parameter (command line argument)
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/$RUNTIME_DATE.status"}	# Currently used status file
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file

FS_ACTIONS_FILE="$MAIN_DIR/scripts/fs-actions_$RUNTIME_DATE.sh"
source $MAIN_DIR/resources/fs-options.rc

# Queue the requested value from the JSON profile file by jq
PROFILE=$(jq '.[] | select(.name=="fs")' $PROFILE_FILE)	# Save our object from the array
check-pf()  {   return $(echo $PROFILE | jq ".fs.$1");  }

CURRENT_MOUNT_OPTIONS=()
FSTAB_MOUNT_OPTIONS=()

# Get mount information from /etc/fstab
cat /etc/fstab | while read line; do
	[[ $line =~ "#" ]] && continue
	L_DEVICE=$(echo line | awk '{print $1;}')
	L_MOUNT_POINT=$(echo line | awk '{print $2;}')
	L_FS_TYPE=$(echo line | awk '{print $3;}')

	L_MOUNT_OPTIONS=$(echo line | awk '{print $4;}')
	L_MOUNT_OPTIONS=${L_MOUNT_OPTIONS/,/ /}

	# Check if the mount point in /etc/fstab exists in our list of covered mount points
	if [[ -n MOUNT_POINTS[$L_MOUNT_POINT] ]] then
		# Check if file system type is the one recommended
		if [[ $L_FS_TYPE -eq $(echo ${MOUNT_POINTS[$L_MOUNT_POINT]} | awk '{print $1;}') ]] then
			echo "FileSystem-Hardening($L_MOUNT_POINT) $ 0" >> $STATUS_FILE
		fi

		# Loop through the mount options of the mount point and check if they are the suitable recommended ones
		for opt in "${MOUNT_OPTIONS[@]}"; do
			[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]]  && continue

			echo "FileSystem-Hardening($L_MOUNT_POINT) $opt 0" >> $STATUS_FILE
			echo "FileSystem-Hardening[$L_MOUNT_POINT]: Mount option $opt is missing from /etc/fstab for $L_MOUNT_POINT mount point, it's recommended to be used.
${MOUNT_OPTIONS[$opt]}" >> $MESSAGES_FILE
		done
	fi
done

# Get current running mount information from /proc/mounts
cat /proc/mounts | while read line; do
	
done

write-hidepid()	{
	SYSTEMD_LOGIND_HIDEPID_FILE="/etc/systemd/system/systemd-logind.service.d/hidepid.conf"
	[[ ! -f $SYSTEMD_LOGIND_HIDEPID_FILE ]] && touch $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "[Service]" >> $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "SupplementaryGroups=proc" >> $SYSTEMD_LOGIND_HIDEPID_FILE
}


echo "$FS_ACTIONS_FILE" >> $ACTIONS_FILE
