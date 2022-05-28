#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Prevent overwriting files, if then the script will exit
set -C

_USAGE_FUNCTION() {
	echo "Usage: $0 (scan - take-action - list-messages - list-actions - clear-all - rotate) -cf [configuration file] -pf [profile file] -mf [messages file] -af [actions file] -d [date to list (messages or actions) in YYYY-MM-DD format]"
}

[[ $(id -u) != 0 ]] && {
	echo "$0: Must run as a root, either by 'systemctl start harden.service' or by 'sudo $0' ."
	_USAGE_FUNCTION
	exit 0
}

RUNTIME_DATE=$(date +%F_%H-%M-%S)	# Runtime date and time

# First argument should specify which mode we are running in
OPERATE_MODE=$1
DEBUG_X=" "
shift
# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
	case $1 in
		-cf|--config-file)	# Use a configuration file from user choice
			CONFIG_FILE=$2
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
		-pf|--profile-file)	# Use a profile file from user choice
			PROFILE_FILE="$2"
			shift 2 
			;;
		-d|--date-to-list)	# This option is used in (list-messages, list-actions) operate modes
			if [[ $OPERATE_MODE == scan ]]; then
				echo "$0: invalid option, ($1) is only used with (list-messages, list-actions) modes"
				_USAGE_FUNCTION
				exit 1
			elif [[ ! $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
				echo "$0: Invalid date format ($2), should be in the YYYY-MM-DD format."
			fi
			DATE_TO_LIST=$2
			shift 2
			;;
		-x)
			DEBUG_X="-x"
			set -x
			shift 1
			;;
		-*|--*)
			echo "Unknown option $1"
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


MAIN_DIR="/usr/share/harden"	# Default Main Directory
cd $MAIN_DIR || { echo "$0: Harden service should be in /usr/share/harden."; exit 1; }

CONFIG_DIR="/etc/harden"	# Default Configuration Directory
if [[ -n $PROFILE_FILE ]] && [[ ! -e $PROFILE_FILE ]]; then
	if [[ -h $CONFIG_DIR/profile-file.json ]]; then
		PROFILE_FILE="$CONFIG_DIR/profile-file.json"	# Use Default User Choice Profile File,
	elif [[ -h $MAIN_DIR/config/profile-file.json ]]; then
		PROFILE_FILE="$MAIN_DIR/config/profile-file.json"	# if not set by a positional parameter (command line argument)
	else
		echo "$0: Critical Error: JSON file \"profile-file.json\" which is the main congifuration file for the Linux Hardening Project, is missing."
		echo "Couldn't find it in: $PROFILE_FILE, or /etc/harden/profile-file.json, or /usr/share/harden/config/profile-file.json"
		exit 1
	fi
fi

SCRIPTS_DIR="$MAIN_DIR/scripts"	# Default Scripts Directory

STATUS_DIR="$MAIN_DIR/status"	# Default Status Directory
MESSAGES_DIR="$MAIN_DIR/messages"	# Default Messages Directory
ACTIONS_DIR="$MAIN_DIR/actions"	# Default Actions Directory

[[ ! -d $STATUS_DIR ]] && mkdir $STATUS_DIR	# Check if Directory exists, and if not then create it
[[ ! -d $MESSAGES_DIR ]] && mkdir $MESSAGES_DIR	# Check if Directory exists, and if not then create it
[[ ! -d $ACTIONS_DIR ]] && mkdir $ACTIONS_DIR	# Check if Directory exists, and if not then create it

CONFIG_FILE=${CONFIG_FILE:="$CONFIG_DIR/harden.conf"}	# Use Default Configuration File,
									# if not set by a positional parameter (command line argument)
PROFILE_FILE=${PROFILE_FILE:="$CONFIG_DIR/profile-file.json"}	# Default User Choice Profile File
MESSAGES_FILE=${MESSAGES_FILE:="$MESSAGES_DIR/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$ACTIONS_DIR/$RUNTIME_DATE.sh"}	# Currently used Actions file

# Redirect stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# (status, messages, actions) files the content of it will also be recorded in the 
# log file.
# Uncomment these lines if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
########################################################
LOGS_DIR="/var/log/harden"	# Default Actions Directory
[[ ! -d $LOGS_DIR ]] && mkdir $LOGS_DIR	# Check if Directory exists, and if not then create it
LOG_FILE="$LOGS_DIR/$(date +%F_%H-%M-%S).log"

if [[ -z $DEBUG_X ]]; then
	[[ -e $LOGS_DIR/harden-last-log ]] && unlink $LOGS_DIR/harden-last-log
	ln -s "$LOG_FILE" $LOGS_DIR/harden-last-log
	echo > "$LOG_FILE"
	exec 2>> "$LOG_FILE"
fi
########################################################

# Print startup message with run time settings
echo "\
Harden service is starting up ...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE" 1>&2

_HARDEN_RUN_FUNCTION()   {
	# Create status and messages and actions file for the current run.
	touch "$MESSAGES_FILE" "$ACTIONS_FILE"

	tail -f "$MESSAGES_FILE" &	# Run tail command in follow mode in the
					# background, so we can get the data from
					# the status file in stdout automatically.
	trap "pkill -P $$" EXIT	# Set a trap condition for the tail command,
					# so it will end, when the process (script) exits.
#	tail -f "$ACTIONS_FILE" &
#	trap "pkill -P $$" EXIT

	# Create/relink a symlink to the last (actions,messages) files
	[[ -h $MESSAGES_DIR/harden-last-messages ]] && unlink $MESSAGES_DIR/harden-last-messages
	[[ -h $ACTIONS_DIR/harden-last-action ]] && unlink $ACTIONS_DIR/harden-last-action
	ln -s "$MESSAGES_FILE" "$MESSAGES_DIR/harden-last-messages"
	ln -s "$ACTIONS_FILE" "$ACTIONS_DIR/harden-last-action"

	SCRIPTS_NAMES=$(jq '.[].script' $PROFILE_FILE)
	SCRIPTS_NAMES=${SCRIPTS_NAMES//\"/}

	for script in $SCRIPTS_NAMES; do
		if [[ -e $script ]]; then
			if [[ ${script%"$(basename $script)"} != "$SCRIPTS_DIR/" ]]; then
				echo "Script $script does not exist in the scripts directory $SCRIPTS_DIR. Skipping $script, due to potential suspecious ." 1>&2
				continue
			fi
			bash "$DEBUG_X" "$script" -mf "$MESSAGES_FILE" -af "$ACTIONS_FILE" -pf "$PROFILE_FILE" 2>>"$LOG_FILE"
		else
			echo "Script $script does not exist. Please, check what is wrong either in the profile-file.json, or if there's any missing package files." 1>&2
		fi
	done

	echo "Harden service has finished"
}

_TAKE_ACTION_FUNCTION()   {
	echo "Taking Actions from file $ACTIONS_DIR/harden-last-actions"
	bash "$ACTIONS_DIR/harden-last-actions"
}

_SHOW_MESSAGES_FUNCTION() {
	if [[ $(find $MESSAGES_DIR/ -maxdepth 1 -type f -name "$DATE_TO_LIST*" | wc -w) == 0 ]]; then
		echo "No messages found for this date ($DATE_TO_LIST)"
	else
		for i in $MESSAGES_DIR/$DATE_TO_LIST*
		do
			cat $i
		done
	fi
}

_SHOW_ACTIONS_FUNCTION()  {
	if [[ $(find "$ACTIONS_DIR/" -maxdepth 1 -type f -name "$DATE_TO_LIST*" | wc -w) == 0 ]]; then
		echo "No actions found for this date ($DATE_TO_LIST)"
	else
		for i in $ACTIONS_DIR/$DATE_TO_LIST*
		do
			cat $i
		done
	fi
}

# Check what mode we are running in
case $OPERATE_MODE in
	scan)
		_HARDEN_RUN_FUNCTION
		;;
	take-action)
		_TAKE_ACTION_FUNCTION
		;;
	list-messages)
		_SHOW_MESSAGES_FUNCTION
		;;
	list-actions)
		_SHOW_ACTIONS_FUNCTION
		;;
	clear-all)
		unlink $ACTIONS_DIR/harden-last-action &> /dev/null
		unlink $MESSAGES_DIR/harden-last-messages &> /dev/null
		unlink $LOGS_DIR/harden-last-log &> /dev/null
		rm -f $MESSAGES_DIR/* $ACTIONS_DIR/* $STATUS_DIR/* $LOGS_DIR/*
		;;
	rotate)	# Remove old/unuseful (actions, messsages, logs) files that are more than a month old (30 days)
		find $MESSAGES_DIR/ $ACTIONS_DIR/ $LOGS_DIR/ -maxdepth 1 -atime +30 -type f
		;;
	*)
		echo "Please specify one of the available modes (scan - take-action - list-messages - list-actions - clear-all - rotate)"
		;;
esac

exit
