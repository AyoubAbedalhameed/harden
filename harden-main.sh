#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

[[ $__DEBUG_X == 1 ]] && set -x

[[ $__RAN_BY_HARDEN_RUN != 1 ]] && {
	echo >&2 "$0 should be called by harden-run"
	exit 1
}

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

	SCRIPTS_NAMES=$(jq '.[].script' "$PROFILE_FILE")
	SCRIPTS_NAMES=${SCRIPTS_NAMES//\"/}

	export __RAN_BY_HARDEN_MAIN
	__RAN_BY_HARDEN_MAIN=1

	for script in $SCRIPTS_NAMES; do
		if [[ -e $script ]]; then
			if [[ ${script%"$(basename $script)"} != "$SCRIPTS_DIR/" ]]; then
				echo >&2 "$0: Script $script does not exist in the scripts directory $SCRIPTS_DIR. Skipping $script, due to it's suspecious location."
				continue
			fi
			echo "Attemting to run $script" >&2
			bash $script  #-m "$MESSAGES_FILE" -a "$ACTIONS_FILE" -p "$PROFILE_FILE"
		else
			echo >&2 "$0: Script $script does not exist. Please, check what is wrong either in the profile-file.json, or if there's any missing package files."
		fi
	done
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

echo "Harden service has finished"

wait

exit
