#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# Different recommended file system hardening options and configuration

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
FileSystem Hardening is starting at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

STATUS_FILE="$MAIN_DIR/status/fs-harden.status"	# Currently used status file

#FS_ACTIONS_FILE="$MAIN_DIR/scripts/fs-actions.sh"

[[ ! -e "$MAIN_DIR/resources/fs-options.rc" ]] && {
	echo >&2 "$0: File System hardening resources file doesn't exist '$MAIN_DIR/resources/fs-options.rc'."
	exit 1
}
source "$MAIN_DIR/resources/fs-options.rc"

#[[ -e "$STATUS_FILE" ]] && source "$STATUS_FILE"

[[ $(_check_profile_file_function fs check) == 0 ]] && exit

_write_hidepid_function()	{
	[[ $(_check_profile_file_function fs action) == 0 ]] && return

	SYSTEMD_LOGIND_HIDEPID_FILE="/etc/systemd/system/systemd-logind.service.d/hidepid.conf"
	[[ ! -f $SYSTEMD_LOGIND_HIDEPID_FILE ]] && touch $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "[Service]" >> $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "SupplementaryGroups=proc" >> $SYSTEMD_LOGIND_HIDEPID_FILE
	systemctl daemon-reload
}

_check_mount_options_function()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$3

	# Subititue the options from the MOUNT_OPTIONS dictionary that is after the 'options=' string, then save them as array
	local REC_MOUNT_OPTIONS
	REC_MOUNT_OPTIONS="${MOUNT_POINTS[L_MOUNT_POINT]#*options=}"

	# Loop through the mount options of the mount point and check if they are the suitable recommended ones
	for opt in $REC_MOUNT_OPTIONS; do
		if [[ $opt == "hidepid" ]] && [[ $L_FS_TYPE == "proc" ]] ; then
			[[ ! -e  "/etc/systemd/system/systemd-logind.service.d/hidepid.conf" ]] && _write_hidepid_function
		fi

		[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]]  && continue

		echo "mounts${L_MOUNT_POINT//\//_}_$opt=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: Mount option $opt is not currently set for $L_MOUNT_POINT mount point, it's recommended to be used." >> "$MESSAGES_FILE"

		opt=${opt%=*}
		[[ -n ${!opt} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $opt: ${!opt}" >> "$MESSAGES_FILE"
	done
}

_cmp_fstab_function()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$3
	local L_DEVICE=$4

	# Compare the current mount point information with the same mount point entry in /etc/fstab
	local FSTAB_LINE FSTAB_FS_TYPE FSTAB_DEVICE FSTAB_MOUNT_OPTIONS

	grep -qE "^[^#]{1}[A-Z,a-z,0-9,=,/,\-]+ $L_MOUNT_POINT " /etc/fstab || {
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point doesn't have any entry in in /etc/fstab" >> "$MESSAGES_FILE"
		return
	}

	FSTAB_LINE="$(grep -qE \'^[^\#]{1}[A-Z,a-z,0-9,=,/,\-]+ $L_MOUNT_POINT \' /etc/fstab)"
	FSTAB_DEVICE="$(echo "$FSTAB_LINE" | awk '{print $1;}')"
	FSTAB_FS_TYPE="$(echo "$FSTAB_LINE" | awk '{print $3;}')"
	FSTAB_MOUNT_OPTIONS="$(echo "$FSTAB_LINE" | awk '{print $4;}')"

	# Compare Device name used for mount point
	if [[ "$FSTAB_DEVICE" == "$L_DEVICE" ]]; then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_DEVICE=0" >> "$STATUS_FILE"
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point device $L_DEVICE is different from the one in /etc/fstab which is $FSTAB_DEVICE." >> "$MESSAGES_FILE"
	fi

	# Compare file system type used for moint point
	if [[ "$FSTAB_FS_TYPE" != "$L_FS_TYPE" ]]; then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> "$STATUS_FILE"

		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point currenlty applied file system type $L_FS_TYPE is different from the one in /etc/fstab which is $FSTAB_FS_TYPE."$'\n'"$FSTAB_FS_TYPE: $([[ -n ${!FSTAB_FS_TYPE} ]] && echo ${!FSTAB_FS_TYPE})" >> "$MESSAGES_FILE"

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

_check_mount_point_function()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$3
	local L_DEVICE=$4

	# Check if the mount point in /proc/mounts exists in our list of covered mount points
	if [[ -n "${MOUNT_POINTS[$L_MOUNT_POINT]}" ]]; then
		# Check if file system type is the one recommended
		local REC_FS_TYPE
		REC_FS_TYPE="$(echo "${MOUNT_POINTS[$L_MOUNT_POINT]}" | awk '{print $1;}')"

		if [[ ! "$L_FS_TYPE" =~ $REC_FS_TYPE ]]; then
			echo "mounts${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> "$STATUS_FILE"
			echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: the currently used file system type $L_FS_TYPE is different from the expected one ${REC_FS_TYPE//\// or }." >> "$MESSAGES_FILE"

			[[ -n ${!REC_FS_TYPE} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: recommended file systemd type is $REC_FS_TYPE: ${!REC_FS_TYPE}" >> "$MESSAGES_FILE"
#			[[ -n ${!L_FS_TYPE} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: current$L_FS_TYPE: ${!L_FS_TYPE}" >> "$MESSAGES_FILE"
		fi

		_check_mount_options_function "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS"
	fi

	_cmp_fstab_function "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS" "$L_FS_TYPE" "$L_DEVICE"
}

# Start by extracting information from /proc/mounts line by line, then check them
while read -r line; do
	L_DEVICE=$(echo $line | awk '{print $1;}')
	L_MOUNT_POINT=$(echo $line | awk '{print $2;}')
	L_FS_TYPE=$(echo $line | awk '{print $3;}')

	L_MOUNT_OPTIONS="$(echo $line | awk '{print $4;}')"
	L_MOUNT_OPTIONS="${L_MOUNT_OPTIONS//,/' '}"	# Replace ',' with ' ' to have them separated for comparison

	_check_mount_point_function "$L_MOUNT_POINT" "$L_MOUNT_OPTIONS" "$L_FS_TYPE" "$L_DEVICE"
done	< /proc/mounts

#[[ $(_check_profile_file_function fs action) == 0 ]] && echo "$FS_ACTIONS_FILE" >> "$ACTIONS_FILE"
