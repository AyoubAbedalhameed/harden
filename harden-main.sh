#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Prevent overwriting files, if then the script will exit
set -C

_USAGE_FUNCTION() {
	echo >&2 "Usage: $0 (scan - take-action - list-messages - list-actions - clear-all - rotate) -cf [configuration file] -pf [profile file] -d [date to list (messages or actions) in YYYY-MM-DD format]"
}

[[ $(id -u) != 0 ]] && {
	echo >&2 "$0: Must run as a root (uid=0,gid=0), either by 'systemctl start harden.service' or by 'sudo $*' ."
	_USAGE_FUNCTION
	exit 0
}

RUNTIME_DATE=$(date '+%s_%F')	# Runtime date and time

# First argument should specify which mode we are running in
OPERATE_MODE=$1
[[ $OPERATE_MODE =~ ^(scan)|(list-actions)|(list-messages)|(take-action)|(rotate)|(clear-all)$ ]] && {
	_USAGE_FUNCTION
	echo >&2 "$0: Please specify one of the available modes (scan - take-action - list-messages - list-actions - clear-all - rotate)"
	exit 0
}

DEBUG_X=""
shift
# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
	case $1 in
		-cf|--config-file)	# Use a configuration file from user choice
			CONFIG_FILE=$2
			shift 2
			;;
		-pf|--profile-file)	# Use a profile file from user choice
			PROFILE_FILE="$2"
			shift 2 
			;;
		-d|--date-to-list)	# This option is used in (list-messages, list-actions) operate modes
			if [[ $OPERATE_MODE == scan ]]; then
				echo >&2 "$0: invalid option, ($1) is only used with (list-messages, list-actions) modes"
				_USAGE_FUNCTION
				exit 1
			elif [[ ! $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
				echo >&2 "$0: Invalid date format ($2), should be in the YYYY-MM-DD format."
				_USAGE_FUNCTION
				exit 0
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
			echo >&2 "$0: Unknown option $1"
			_USAGE_FUNCTION
			exit 0
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
if [[ $(pwd) != "$MAIN_DIR" ]];then
	cd $MAIN_DIR || { echo >&2 "$0: Couldn't change running directory to $MAIN_DIR, where Linux Harden service files should be in."; exit 1; }
fi

# Checking profile file value and existance
CONFIG_DIR="/etc/harden"	# Default Configuration Directory
CONFIG_FILE=${CONFIG_FILE:="$CONFIG_DIR/harden.conf"}	# Use Default Configuration File,
									# if not set by a positional parameter (command line argument)
if [[ -n $PROFILE_FILE ]] && [[ ! -e $PROFILE_FILE ]]; then
	echo >&2 "$0: Invalid data for -pf (profile file): $PROFILE_FILE no such file."
	_USAGE_FUNCTION
	exit 1
elif [[ -z $PROFILE_FILE ]] && [[ -e $CONFIG_DIR/profile-file.json ]]; then
	PROFILE_FILE="$CONFIG_DIR/profile-file.json"	# Use Default User Choice Profile File,
elif [[ -z $PROFILE_FILE ]] && [[ -e $MAIN_DIR/config/profile-file.json ]]; then
	PROFILE_FILE="$MAIN_DIR/config/profile-file.json"	# if not set by a positional parameter (command line argument)
elif [[ -z $PROFILE_FILE ]]; then
	echo >&2 "$0: Critical Error: JSON file \"profile-file.json\" which is the main congifuration file for the Linux Hardening Service, is missing. \
Couldn't find it in: /etc/harden/profile-file.json, or /usr/share/harden/config/profile-file.json"
	exit 1
fi

SCRIPTS_DIR="$MAIN_DIR/scripts"	# Default Scripts Directory

STATUS_DIR="$MAIN_DIR/status"	# Default Status Directory
MESSAGES_DIR="$MAIN_DIR/messages"	# Default Messages Directory
ACTIONS_DIR="$MAIN_DIR/actions"	# Default Actions Directory
mkdir -p $STATUS_DIR	# 'mkdir' command with '-p' option won't give an error if the dir. exists, otherwise it will create
mkdir -p $MESSAGES_DIR
mkdir -p $ACTIONS_DIR

MESSAGES_FILE="$MESSAGES_DIR/harden-messages_$RUNTIME_DATE"	# Currently used messages file
ACTIONS_FILE="$ACTIONS_DIR/harden-action_$RUNTIME_DATE.sh"	# Currently used Actions file

# Redirect stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# (status, messages, actions) files the content of it will also be recorded in the 
# log file.
# Uncomment these lines if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
########################################################

if [[ $__LAUNCHED_BY_SYSTEMD == 1 ]]; then	# Only add Syslog Identifier prefix <x>
	# Default STDOUT to be prefixed with syslog identifier <6> for INFO, and save old STDOUT value in fd '6'
	exec 6>&1 1> >(while read -r __INFO; do echo >&6 "<6>$__INFO"; done)
	trap 'exec >&6-' EXIT
	trap 'exec >&1-' EXIT

	# Default STDERR to be prefixed with syslog identifier <7> for DEBUG
	exec 7>&2 2> >(while read -r __DEBUG; do echo >&7 "<7>$__DEBUG"; done)
	trap 'exec >&7-' EXIT
	trap 'exec >&2-' EXIT

	# Default messages to be prefixed with syslog identifier <5> for NOTICE, redirect to file discreptor '6' (the saved STDOUT)
	exec 5> >(while read -r __NOTICE; do echo >&6 "<5>$__NOTICE"; done)
	trap 'exec >&5-' EXIT

elif [[ -z $DEBUG_X ]]; then
	# Write every thing to a log file, in a formatted way with full usefull info
	LOGS_DIR="/var/log/harden"	# Default Actions Directory
	mkdir -p $LOGS_DIR	# Check if Directory exists, and if not then create it
	LOG_FILE="$LOGS_DIR/harden-logs-${RUNTIME_DATE}.log"

	ln -fs "$LOG_FILE" $LOGS_DIR/harden-last-log
	touch "$LOG_FILE"

	# Default STDOUT to be prefixed with syslog identifier <6> for INFO, with more logging information then redirect to log file
	exec 1> >(while read -r __INFO; do echo "$(date '+%F %T') $HOSTNAME harden-service[$$]: <info> [$(date %s.%^4N)] $__INFO" >> "$LOG_FILE" ; done)
	trap 'exec >&1-' EXIT

	# Default STDERR to be prefixed with syslog identifier <7> for DEBUG, with more logging information then redirect to log file
	exec 2> >(while read -r __LOG_DEBUG; do echo "$(date '+%F %T') $HOSTNAME harden-service[$$]: <debug> [$(date %s.%^4N)] $__LOG_DEBUG" >> "$LOG_FILE"; done)
	trap 'exec >&2-' EXIT

	# Default messages to be prefixed with syslog identifier <5> for NOTICE, with more logging information then redirect to log file
	exec 5> >(while read -r __NOTICE; do echo "$(date '+%F %T') $HOSTNAME harden-service[$$]: <notice> [$(date %s.%^4N)] $__NOTICE" >> "$LOG_FILE"; done)
	trap 'exec >&5-' EXIT
fi

########################################################
# SysLoglevels prefixes, from sd-daemon manual
# <0> <emerg>	system is unusable
# <1> <alert>	action must be taken immediately
# <2> <crit>	critical conditions
# <3> <err>		error conditions
# <4> <warning>	warning conditions
# <5> <notice>	normal but significant condition
# <6> <info>	informational
# <7> <debug>	debug-level messages

# Print startup message with run time settings
echo >&2 "\
Harden service is starting up ...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

_HARDEN_RUN_FUNCTION()   {
	# Create status and messages and actions file for the current run.
	touch "$MESSAGES_FILE" "$ACTIONS_FILE"

	cat >&5 <"$MESSAGES_FILE" &
	trap "pkill -P $$" EXIT

	# Create/relink a symlink to the last (actions,messages) files, '-f' option will force even if dest. file exists
	ln -fs "$MESSAGES_FILE" "$MESSAGES_DIR/harden-last-messages"
	ln -fs "$ACTIONS_FILE" "$ACTIONS_DIR/harden-last-action"

	SCRIPTS_NAMES=$(jq '.[].script' $PROFILE_FILE)
	SCRIPTS_NAMES=${SCRIPTS_NAMES//\"/}

	for script in $SCRIPTS_NAMES; do
		if [[ -e $script ]]; then
			if [[ ${script%"$(basename $script)"} != "$SCRIPTS_DIR/" ]]; then
				echo >&2 "$0: Script $script does not exist in the scripts directory $SCRIPTS_DIR. Skipping $script, due to it's suspecious location."
				continue
			fi
			bash "$DEBUG_X" "$script" -mf "$MESSAGES_FILE" -af "$ACTIONS_FILE" -pf "$PROFILE_FILE"
		else
			echo >&2 "$0: Script $script does not exist. Please, check what is wrong either in the profile-file.json, or if there's any missing package files."
		fi
	done

	echo "Harden service has finished"
}

_TAKE_ACTION_FUNCTION()   {
	echo "Taking Actions from file $ACTIONS_DIR/harden-last-actions (Not ready yet, and won't do anything -_-)."
#	bash "$ACTIONS_DIR/harden-last-actions"
}

_SHOW_MESSAGES_FUNCTION() {
	# Check if any files apply to the requested date
	if [[ $(find $MESSAGES_DIR/ -maxdepth 1 -type f) =~ ^$MESSAGES_DIR/harden-messages_"$DATE_TO_LIST"_[0-9]{2}-[0-9]{2}-[0-9]{2} ]]; then
		echo >&2 "$0: No messages found for this date ($DATE_TO_LIST)"
	else
		for i in $MESSAGES_DIR/$DATE_TO_LIST*; do
			cat "$i"
		done
	fi
}

_SHOW_ACTIONS_FUNCTION()  {
	if [[ $(find "$ACTIONS_DIR/" -maxdepth 1 -type f) =~  ^$MESSAGES_DIR/harden-action_"$DATE_TO_LIST"_[0-9]{2}-[0-9]{2}-[0-9]{2} ]]; then
		echo >&2 "$0: No actions found for this date ($DATE_TO_LIST)"
	else
		for i in $ACTIONS_DIR/$DATE_TO_LIST*; do
			cat "$i"
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
	clear-all)		# Clean all (non core) data files created by us in the past
		unlink $ACTIONS_DIR/harden-last-action &> /dev/null
		unlink $MESSAGES_DIR/harden-last-messages &> /dev/null
		unlink $LOGS_DIR/harden-last-log &> /dev/null
#		rm -f $MESSAGES_DIR/* $ACTIONS_DIR/* $STATUS_DIR/* $LOGS_DIR/*		# Dangerous and still needs more testing
		;;
	rotate)	# Remove old/unuseful (actions, messsages, logs) files that are more than a month old (30 days)
		find $MESSAGES_DIR/ $ACTIONS_DIR/ $LOGS_DIR/ -maxdepth 1 -atime +30 -type f
		;;
esac

exit
