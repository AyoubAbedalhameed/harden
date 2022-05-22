#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# Different recommended file system hardening options and configuration

usage() {   echo "Usage: $0 -md/--main-directory [main directory] -pf/--profile-file [profile file] \
-mf/--messages-file [messages file] -af/--actions-file [actions file]"; }

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
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file

STATUS_FILE="$MAIN_DIR/status/fs.status"	# Currently used status file
FS_ACTIONS_FILE="$MAIN_DIR/scripts/fs-actions_$RUNTIME_DATE.sh"

source $MAIN_DIR/resources/fs-options.rc
[[ -f $STATUS_FILE ]] && source $STATUS_FILE

# Queue the requested value from the JSON profile file by jq
PROFILE=$(jq '.[] | select(.name=="fs")' $PROFILE_FILE)	# Save our object from the array
check-pf()  {   return $(echo $PROFILE | jq ".fs.$1");  }

[[ $(check-pf check) == 0 ]] && exit

write-hidepid()	{
	[[ $(check-pf action) == 0 ]] && return

	SYSTEMD_LOGIND_HIDEPID_FILE="/etc/systemd/system/systemd-logind.service.d/hidepid.conf"
	[[ ! -f $SYSTEMD_LOGIND_HIDEPID_FILE ]] && touch $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "[Service]" >> $SYSTEMD_LOGIND_HIDEPID_FILE
	echo "SupplementaryGroups=proc" >> $SYSTEMD_LOGIND_HIDEPID_FILE
}

check-mount-options()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$3

	# Subititue the options from the MOUNT_OPTIONS dictionary that is after the 'options=' string, then save them as array
	local REC_MOUNT_OPTIONS=(${MOUNT_OPTIONS[L_MOUNT_POINT]#*options=})

	# Loop through the mount options of the mount point and check if they are the suitable recommended ones
	for opt in "${REC_MOUNT_OPTIONS[@]}"; do
		if [[ $opt == "hidepid" ]] then
			[[ ! -f  "/etc/systemd/system/systemd-logind.service.d/hidepid.conf" ]] && write-hidepid
		fi

		[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]]  && continue

		echo "mounts${L_MOUNT_POINT//\//_}-$opt 0" >> $STATUS_FILE
		echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: Mount option $opt is not currently set for $L_MOUNT_POINT mount point, it's recommended to be used." >> $MESSAGES_FILE
		[[ -n ${MOUNT_OPTIONS[$opt]} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $opt: ${MOUNT_OPTIONS[$opt]}" >> $MESSAGES_FILE
	done
}

cmp-fstab()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$2
	local L_DEVICE=$4

	# Compare the current mount point information with the same mount point entry in /etc/fstab
	local FSTAB_LINE="$(grep $L_MOUNT_POINT /etc/fstab)"

	local FSTAB_DEVICE="$(echo $FSTAB_LINE | awk '{print $1;}')"
	local FSTAB_MOUNT_OPTIONS="$(echo $FSTAB_LINE | awk '{print $4;}')"
	local FSTAB_FS_TYPE="$(echo $FSTAB_LINE | awk '{print $3;}')"

	# Compare Device name used for mount point
	if [[ $FSTAB_DEVICE == $L_DEVICE ]] then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_DEVICE=0" >> $STATUS_FILE
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point device $L_DEVICE is different from the one in /etc/fstab which is $FSTAB_DEVICE." >> $MESSAGES_FILE
	fi
	# Compare file system type used for moint point
	if [[ $FSTAB_FS_TYPE == $L_FS_TYPE ]] then
		echo "fstab${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> $STATUS_FILE
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point currenlty applied file system type $L_FS_TYPE is different from the one in /etc/fstab which is $FSTAB_FS_TYPE." >> $MESSAGES_FILE
		[[ -n ${FS_TYPES[$FSTAB_FS_TYPE]} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $FSTAB_FS_TYPE: ${FS_TYPES[$FSTAB_FS_TYPE]}" >> $MESSAGES_FILE
		[[ -n ${FS_TYPES[$L_FS_TYPE]} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $L_FS_TYPE: ${FS_TYPES[$L_FS_TYPE]}" >> $MESSAGES_FILE
	fi

	for opt in $FSTAB_MOUNT_OPTIONS; do
		[[ $L_MOUNT_OPTIONS =~ (^|[[:space:]])"$opt"($|[[:space:]]) ]] && continue
		echo "fstab${L_MOUNT_POINT//\//_}-$opt=0" >> $STATUS_FILE
		echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: Mount point currently running (applied) mount options is missing $opt option which is specified in /etc/fstab, if it wasn't from you and feels suspeciuos, remount it by (mount -a)." >> $MESSAGES_FILE
		[[ -n ${MOUNT_OPTIONS[$opt]} ]] && echo "FileSystem-Hardening[fstab][$L_MOUNT_POINT]: $opt: ${MOUNT_OPTIONS[$opt]}" >> $MESSAGES_FILE
	done
}

check-mount-point()	{
	local L_MOUNT_POINT=$1
	local L_MOUNT_OPTIONS=$2
	local L_FS_TYPE=$2
	local L_DEVICE=$4

	# Check if the mount point in /proc/mounts exists in our list of covered mount points
	if [[ -n "${MOUNT_POINTS[$L_MOUNT_POINT]}" ]] then
		# Check if file system type is the one recommended
		local REC_FS_TYPE="$(echo ${MOUNT_POINTS[$L_MOUNT_POINT]} | awk '{print $1;}')"

		if [[ $L_FS_TYPE != $REC_FS_TYPE ]] then
			echo "mounts${L_MOUNT_POINT//\//_}-$L_FS_TYPE=0" >> $STATUS_FILE
			echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: the currently used file system type $L_FS_TYPE is different from the expected one $REC_FS_TYPE." >> $MESSAGES_FILE
			[[ -n ${FS_TYPES[$REC_FS_TYPE]} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $REC_FS_TYPE: ${FS_TYPES[$REC_FS_TYPE]}" >> $MESSAGES_FILE
			[[ -n ${FS_TYPES[$L_FS_TYPE]} ]] && echo "FileSystem-Hardening[mounts][$L_MOUNT_POINT]: $L_FS_TYPE: ${FS_TYPES[$L_FS_TYPE]}" >> $MESSAGES_FILE
		fi

		check-mount-options $L_MOUNT_POINT $L_MOUNT_OPTIONS
	fi

	cmp-fstab $L_MOUNT_POINT $L_MOUNT_OPTIONS $L_FS_TYPE $L_DEVICE
}

# Start by extracting information from /proc/mounts line by line, then check them
cat /proc/mounts | while read line; do
	L_DEVICE="$(echo $line | awk '{print $1;}')"
	L_MOUNT_POINT="$(echo $line | awk '{print $2;}')"
	L_FS_TYPE="$(echo $line | awk '{print $3;}')"

	L_MOUNT_OPTIONS="$(echo $line | awk '{print $4;}')"
	L_MOUNT_OPTIONS="${L_MOUNT_OPTIONS/,/ /}"	# Replace ',' with ' ' to have them separated for comparison

	check-mount-point $L_MOUNT_POINT $L_MOUNT_OPTIONS $L_FS_TYPE $L_DEVICE
done

[[ $(check-pf action) == 0 ]] && echo "$FS_ACTIONS_FILE" >> $ACTIONS_FILE
