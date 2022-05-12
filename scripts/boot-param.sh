#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# GRUB Boot Parameters hardening

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

check-pf()  {   return $(jq ".boot.$1.$2" $PROFILE_FILE);  }

MAIN_DIR=${MAIN_DIR:="/usr/share/harden"}
PROFILE_FILE=${PROFILE_FILE:="/etc/harden/admin-choice.profile"}    # Use Default User Choice Profile File, 
                                                                    # if not set by a positional parameter (command line argument)
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/$RUNTIME_DATE.status"} # Currently used status file
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}  # Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}  # Currently used Actions file

RESOURSES_FILE="$MAIN_DIR/resources/boot-parameters.rc"
source $RESOURSES_FILE

GRUB_FILE="/etc/default/grub"
LINE="GRUB_CMDLINE_LINUX="
DLINE="GRUB_CMDLINE_LINUX_DEFAULT="

if grep -q "$LINE" "$GRUB_FILE" then
	CURRENT=$(grep $LINE $GRUB_FILE)
	CURRENT=${CURRENT##$LINE}
	CURRENT=${CURRENT#\"}
	CURRENT=${CURRENT%\"}

	for i in $CURRENT; do

	done
fi

if grep -q "$DLINE" "$GRUB_FILE" then
	DCURRENT=$(grep $DLINE $GRUB_FILE)
	DCURRENT=${DCURRENT##$DLINE}
	DCURRENT=${DCURRENT#\"}
	DCURRENT=${DCURRENT%\"}

	for i in $DCURRENT; do

	done
fi
