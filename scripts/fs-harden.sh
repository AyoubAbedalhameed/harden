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

# Queue the requested value from the JSON profile file by jq
PROFILE=$(jq '.[] | select(.name=="fs")' $PROFILE_FILE)	# Save our object from the array
check-pf()  {   return $(echo $PROFILE | jq ".fs.$1");  }

source $MAIN_DIR/resources/fs-options.rc

check-fstab() {
  FS_FILE="/etc/fstab"
}

check-proc-mount() {
  FS_FILE="/proc/mounts"
}

check-fstab
check-proc-mounts
