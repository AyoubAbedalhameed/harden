#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# Different recommended file system hardening options and configuration

_USAGE_FUNCTION() {
	echo "Usage: $0 -md [main directory] -pf [profile file] -st [status file] -mf [messages file] -af [actions file]";
}

CURRENT_USER_NAME=$(id -un)
CURRENT_USER_ID=$(id -u)
[[ $CURRENT_USER_ID != 0 ]] && {
	echo "$0: Must run as a root (uid=0, gid=0) (currently running as $CURRENT_USER_NAME), either by 'systemctl start harden.service' (which is defaulted to be) or by using 'sudo $0' ."
	_USAGE_FUNCTION
	exit 0
}

RUNTIME_DATE=$(date +%F_%H-%M-%S)	# Runtime date and time

# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
	case $1 in
		-pf|--profile-file)
			if [[ ! -e $2 ]]; then echo "$0: Invalid input for profile file (-pf) $PROFILE_FILE, file doesn't exist. Going to use the default ones (/etc/harden/profile-file.json or /usr/share/harden/config/profile-file.json)"
			else PROFILE_FILE=$2
			fi
			shift 2
			;;
		-sf|--status-file)
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
			echo "$0: Invalid argument $1"
			_USAGE_FUNCTION
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

MAIN_DIR=$(pwd)
MAIN_DIR=${MAIN_DIR%/scripts}

if [[ ! -e $PROFILE_FILE ]]; then
	if [[ -h /etc/harden/profile-file.json ]]; then
		PROFILE_FILE="etc/harden/profile-file.json"	# Use Default User Choice Profile File,
	elif [[ -h $MAIN_DIR/config/profile-file.json ]]; then
		PROFILE_FILE="$MAIN_DIR/config/profile-file.json"	# if not set by a positional parameter (command line argument)
	else
		echo "$0: Critical Error: JSON file \"profile-file.json\" which is the main congifuration file for the Linux Hardening Project, is missing."
		echo "Couldn't find it in: $PROFILE_FILE, or /etc/harden/profile-file.json, or /usr/share/harden/config/profile-file.json"
		exit 1
	fi

	echo "$0: Using $PROFILE_FILE for the current run as profile-file."
fi

MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/fs-harden-$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/fs.status"}	# Currently used status file

FS_ACTIONS_FILE="$MAIN_DIR/scripts/fs-actions.sh"

source "$MAIN_DIR/resources/fs-options.rc"
[[ -f "$STATUS_FILE" ]] && source "$STATUS_FILE"

# Queue the requested value from the JSON profile file by jq
_CHECK_PROFILE_FILE_FUNCTION()  {
	PF_VALUE="$*"
	jq '.[] | select(.name=="fs")' "$PROFILE_FILE" | jq ".fs.${PF_VALUE// /.}"
}

[[ $(_CHECK_PROFILE_FILE_FUNCTION check) == 0 ]] && exit

_WRITE_HIDEPID_FUNCTION()	{
	[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 0 ]] && return

	SYSTEMD_LOGIND_HIDEPID_FILE="/etc/systemd/system/systemd-logind.service.d/hidepid.conf"
	[[ ! -f $SYSTEMD_LOGIND_HIDEPID_FILE ]] && touch $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "[Service]" >> $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "SupplementaryGroups=proc" >> $SYSTEMD_LOGIND_HIDEPID_FILE
}

_CHECK_MOUNT_OPTIONS_FUNCTION()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$3

	# Subititue the options from the MOUNT_OPTIONS dictionary that is after the 'options=' string, then save them as array
	local REC_MOUNT_OPTIONS
	REC_MOUNT_OPTIONS="${MOUNT_POINTS[L_MOUNT_POINT]#*options=}"

	# Loop through the mount options of the mount point and check if they are the suitable recommended ones
	for opt in $REC_MOUNT_OPTIONS; do
		if [[ $opt == "hidepid" ]]; then
			[[ ! -f  "/etc/systemd/system/systemd-logind.service.d/hidepid.conf" ]] && _WRITE_HIDEPID_FUNCTION
		fi

		[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]]  && continue

		echo "mounts${L_MOUNT_POINT//\//_}_$opt=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: Mount option $opt is not currently set for $L_MOUNT_POINT mount point, it's recommended to be used." >> "$MESSAGES_FILE"
		opt=${opt%=*}
		[[ -n ${!opt} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $opt: ${!opt}" >> "$MESSAGES_FILE"
	done
}

_CMP_FSTAB_FUNCTION()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$2
	local L_DEVICE=$4

	# Compare the current mount point information with the same mount point entry in /etc/fstab
	local FSTAB_LINE
	local FSTAB_FS_TYPE
	local FSTAB_DEVICE
	local FSTAB_MOUNT_OPTIONS
	FSTAB_LINE="$(grep "$L_MOUNT_POINT" /etc/fstab)"
	FSTAB_DEVICE="$(echo "$FSTAB_LINE" | awk '{print $1;}')"
	FSTAB_MOUNT_OPTIONS="$(echo "$FSTAB_LINE" | awk '{print $4;}')"
	FSTAB_FS_TYPE="$(echo "$FSTAB_LINE" | awk '{print $3;}')"

	# Compare Device name used for mount point
	if [[ "$FSTAB_DEVICE" == "$L_DEVICE" ]]; then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_DEVICE=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point device $L_DEVICE is different from the one in /etc/fstab which is $FSTAB_DEVICE." >> "$MESSAGES_FILE"
	fi

	# Compare file system type used for moint point
	if [[ "$FSTAB_FS_TYPE" != "$L_FS_TYPE" ]]; then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point currenlty applied file system type $L_FS_TYPE is different from the one in /etc/fstab which is $FSTAB_FS_TYPE." >> "$MESSAGES_FILE"
		[[ -n ${FS_TYPES[$FSTAB_FS_TYPE]} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $FSTAB_FS_TYPE: ${FS_TYPES[$FSTAB_FS_TYPE]}" >> "$MESSAGES_FILE"
		[[ -n ${!L_FS_TYPE} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $L_FS_TYPE: ${!L_FS_TYPE}" >> "$MESSAGES_FILE"
	fi

	for opt in $FSTAB_MOUNT_OPTIONS; do
		[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]] && continue
		echo "fstab${L_MOUNT_POINT//\//_}-$opt=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point currently running (applied) mount options is missing $opt option which is specified in /etc/fstab, if it wasn't from you and feels suspeciuos, remount it by (mount -a)." >> "$MESSAGES_FILE"
		opt=${opt%=*}
		[[ -n ${!opt} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $opt: ${!opt}" >> "$MESSAGES_FILE"
	done
}

_CHECK_MOUNT_POINT_FUNCTION()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$2
	local L_DEVICE=$4

	# Check if the mount point in /proc/mounts exists in our list of covered mount points
	if [[ -n "${MOUNT_POINTS[$L_MOUNT_POINT]}" ]]; then
		# Check if file system type is the one recommended
		local REC_FS_TYPE
		REC_FS_TYPE="$(echo "${MOUNT_POINTS[$L_MOUNT_POINT]}" | awk '{print $1;}')"

		if [[ ! "$L_FS_TYPE" =~ $REC_FS_TYPE ]]; then
			echo "mounts${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> "$STATUS_FILE"
			echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: the currently used file system type $L_FS_TYPE is different from the expected one ${REC_FS_TYPE//\// or }." >> "$MESSAGES_FILE"
			[[ -n ${FS_TYPES[$REC_FS_TYPE]} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $REC_FS_TYPE: ${FS_TYPES[$REC_FS_TYPE]}" >> "$MESSAGES_FILE"
			[[ -n ${!L_FS_TYPE} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $L_FS_TYPE: ${!L_FS_TYPE}" >> "$MESSAGES_FILE"
		fi

		_CHECK_MOUNT_OPTIONS_FUNCTION "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS"
	fi

	_CMP_FSTAB_FUNCTION "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS" "$L_FS_TYPE" "$L_DEVICE"
}

# Start by extracting information from /proc/mounts line by line, then check them
cat /proc/mounts | while read line; do
	L_DEVICE="$(echo $line | awk '{print $1;}')"
	L_MOUNT_POINT="$(echo $line | awk '{print $2;}')"
	L_FS_TYPE="$(echo $line | awk '{print $3;}')"

	L_MOUNT_OPTIONS="$(echo $line | awk '{print $4;}')"
	L_MOUNT_OPTIONS="${L_MOUNT_OPTIONS/,/ /}"	# Replace ',' with ' ' to have them separated for comparison

	_CHECK_MOUNT_POINT_FUNCTION "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS" "$L_FS_TYPE" "$L_DEVICE"
done

[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 0 ]] && echo "$FS_ACTIONS_FILE" >> "$ACTIONS_FILE"
