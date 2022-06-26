#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

[[ $__RAN_BY_HARDEN_RUN != 1 ]] && {
	echo >&2 "$0 should be called by harden-run"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
Harden service is starting up as pid =$$ at $(date '+%F %T %s.%^4N') ...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

_harden_run_function()   {
	local SCRIPTS_NAMES
	# Create status and messages and actions file for the current run.
	touch "$MESSAGES_FILE"

	tail -f "$MESSAGES_FILE" >&5 &
	trap "pkill -P $$" EXIT

	# Create/relink a symlink to the last (actions,messages) files, '-f' option will force even if dest. file exists
	ln -fs "$MESSAGES_FILE" "$MESSAGES_DIR/harden-last-messages"
	ln -fs "$ACTIONS_FILE" "$ACTIONS_DIR/harden-last-action"
	ln -fs "$REPORT_FILE" "$REPORT_DIR/harden-last-report.html"

	SCRIPTS_NAMES=$(jq '.[].script' "$PROFILE_FILE")
	SCRIPTS_NAMES=${SCRIPTS_NAMES//\"/}

	# This varibale is declared with readonly and export attributes, when the subshells/child-scripts ran, from it's
	# existence and value they will know there parent who called them is the harden-main.sh script, and the enviroment
	# is ready for them to run as they are supposed to be
	declare -xr __RAN_BY_HARDEN_MAIN=1

	for script in $SCRIPTS_NAMES; do
		if [[ -e $script ]]; then
			if [[ ! $script =~ ^$SCRIPTS_DIR/[a-z,A-Z,0-9,=,_,.,:,\,,\-]+$ ]]; then
				echo >&2 "$0: Script $script does not exist in the scripts directory $SCRIPTS_DIR. Skipping $script, due to it's suspecious location."
				continue
			fi
			echo "Attemting to run $script" >&2
			bash $script
		else
			echo >&2 "$0: Script $script does not exist. Please, check what is wrong either in the profile-file.json, or if there's any missing package files."
		fi
	done

	# Create a HTML report of the scan
	bash harden-report.sh
}

_take_action_function()   {
	local SCRIPT_NAME ARGS TYPE
	echo "Taking Actions from the file that is pointed to by this symlink $ACTIONS_DIR/harden-last-action"

	while read -r line; do
#		SCRIPT_NAME=$(echo "$line" | awk '{print $1;}')		# Get the script name
		SCRIPT_NAME=$line
#		ARGS="${line##"$SCRIPT_NAME "}"			# Get the arguments that are supposed to be passed to the script
		TYPE=$(basename "$SCRIPT_NAME")
		TYPE=${TYPE%%-*}					# Actions file has their type as the prefix of the file name, with '-' after it

		# For caution, we will not accept any script file outside of the default scripts or actions directories
		[[ ! $SCRIPT_NAME =~ ^$MAIN_DIR/(actions|scripts)/[a-z,A-Z,0-9,=,_,.,\-]+$ ]] && {
			echo >&2 "$0: from _take_action_function(): action file '$SCRIPT_NAME' of module '$TYPE' is not in the '$ACTIONS_DIR' or the '$SCRIPTS_DIR' directories,"
			echo >&2 " so it will not be allowed to execute. Skipping..."
			continue
		}

		# After getting the module type of the script, check the profile file if this module is allowed to take action.
		[[ $(_check_profile_file_function $TYPE action) != 1 ]] &&	{
			echo >&2 "$0: from _take_action_function(): action file $SCRIPT_NAME is considered as of type/module: $TYPE, this module is not allowed to take actions."
		}

		# if the module allowed to take actions, then run it with it's specified arguments
		# For testng we will just print not execute
		echo "bash $SCRIPT_NAME $ARGS"
		bash "$SCRIPT_NAME"
	done  < "$ACTIONS_DIR/harden-last-action"
}

_show_messages_function() {
	# Check if any files apply to the requested date
	if [[ $(find $MESSAGES_DIR/ -maxdepth 1 -type f) =~ ^$MESSAGES_DIR/harden-messages_"$DATE_TO_LIST"_[0-9]{2}-[0-9]{2}-[0-9]{2} ]]; then
		echo >&2 "$0: No messages found for this date ($DATE_TO_LIST)"
	else
		for i in $MESSAGES_DIR/$DATE_TO_LIST*; do
			cat "$i"
		done
	fi
}


# Check what mode we are running in
case $OPERATE_MODE in
	scan)
		_harden_run_function
		;;
	take-action)
		_take_action_function
		;;
	list-messages)
		_show_messages_function
		;;
	clear-all)		# Clean all (non core) data files created by us in the past
		cd "$MAIN_DIR" || exit
		unlink actions/harden-last-action &> /dev/null
		unlink messages/harden-last-messages &> /dev/null
		unlink /var/log/harden/harden-last-log &> /dev/null
		[[ -d ./messages ]] && rm -r ./messages/*
		[[ -d ./actions ]] && rm -r ./actions/*
		[[ -d ./status ]] && rm -r ./status/*
		[[ -d ./reports ]] && rm -r ./reports/*
		[[ -d /var/log/harden ]] && rm -r /var/log/harden/*
#		rm -r messages/* actions/* status/* reports/* /var/log/harden/*		# Dangerous and still needs more testing
		;;
	rotate)	# Remove old/unuseful (actions, messsages, logs) files that are more than a month old (30 days)
		find $MESSAGES_DIR/ $ACTIONS_DIR/ $LOGS_DIR/ $REPORT_DIR/ -maxdepth 1 -atime +30 -type f -delete
		;;
esac

echo "Harden service has finished"
