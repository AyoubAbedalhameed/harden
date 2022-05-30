#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

_USAGE_FUNCTION() {
	echo >&2 "Usage: $0 -md [main directory] -pf [profile file (JSON format)] -st [status file] -mf [messages file] -af [actions file]";
}

[[ $(id -u) != 0 ]] && {
	echo >&2 "$0: Must run as a root, either by 'systemctl start harden.service' or by 'sudo $0' ."
	_USAGE_FUNCTION
	exit 0
}

RUNTIME_DATE=$(date '+%s_%F')	# Runtime date and time

# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
	case $1 in
		-pf|--profile-file)
			if [[ ! -e $2 ]]; then 
				echo >&2 "$0: Invalid input for profile file (-pf) $PROFILE_FILE, file doesn't exist. Going to use the default ones (/etc/harden/profile-file.json or /usr/share/harden/config/profile-file.json)"
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
			echo >&2 "$0: Invalid argument $1"
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

MAIN_DIR=$(pwd)
MAIN_DIR=${MAIN_DIR%/scripts}

if [[ ! -e $PROFILE_FILE ]]; then
	if [[ -h /etc/harden/profile-file.json ]]; then
		PROFILE_FILE="etc/harden/profile-file.json"	# Use Default User Choice Profile File,
	elif [[ -h $MAIN_DIR/config/profile-file.json ]]; then
		PROFILE_FILE="$MAIN_DIR/config/profile-file.json"	# if not set by a positional parameter (command line argument)
	else
		echo >&2 "$0: Critical Error: JSON file \"profile-file.json\" which is the main congifuration file for the Linux Hardening Project, is missing. \
Couldn't find it in: $PROFILE_FILE, or /etc/harden/profile-file.json, or /usr/share/harden/config/profile-file.json"
		exit 1
	fi

	echo >&2 "$0: Using $PROFILE_FILE for the current run as profile-file."
fi

MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/kernel-harden_$RUNTIME_DATE"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/kernel-harden_$RUNTIME_DATE.sh"}	# Currently used Actions file
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/kernel-harden.status"}	# Currently used status file

KERNEL_ACTIONS_FILE="$MAIN_DIR/actions/kernel-actions.sh"

echo ""
echo "Kernel Hardening script has started..."

# Queue the requested value from the JSON profile file by jq
#PROFILE=$(jq '.[] | select(.name=="kernel")' "$PROFILE_FILE")	# Save our object from the array

_CHECK_PROFILE_FILE_FUNCTION()  {
	PF_VALUE="$*"
	jq '.[] | select(.name=="kernel")' "$PROFILE_FILE" | jq ".kernel.${PF_VALUE// /.}"
}

_CHECK_PARAM_FUNCTION()	{
	local PARAMETERS_FILE
	PARAMETERS_FILE="$MAIN_DIR/resources/kernel-parameters.rc"
	source "$PARAMETERS_FILE"

	VAL_INDEX=0
	MES_INDEX=1
	TYPE_INDEX=2

	# 'sed' here is used to extract only the dictionary keys that ends with ',0', so we loop only once on each parameter once
	for PARAM in $(echo "${!kernel[@]}" | sed 's/[a-z\0-9\.\_\-]*,[1-2]//g'); do
		PARAM="${PARAM%,*}"	# Substring from the begging to the comma (,) to get the parameter name without the index
		MESSAGE="${kernel[$PARAM,$MES_INDEX]}"
		TYPE="${kernel[$PARAM,$TYPE_INDEX]}"
		RECOMMENDED_VAL="${kernel[$PARAM,$VAL_INDEX]}"
		RECOMMENDED_VAL="${RECOMMENDED_VAL//,/$'\t'}"	# Replace commas (,) with tabs (\t), if exists

		[[ $(_CHECK_PROFILE_FILE_FUNCTION "$TYPE" check) != 1 ]]  && continue	# Skip checking this parameter if profile file says so
		CURRENT_VAL="$(sysctl -en "$PARAM")"
		CURRENT_VAL="${CURRENT_VAL//$'\t'/,}"

		[[ -z "$CURRENT_VAL" ]]   && continue

		# Compare current value with recommended one
		[[ "$CURRENT_VAL" == "$RECOMMENDED_VAL" ]] && continue
		# Print Message
		echo "Kernel-Parameter-Hardening[$PARAM]: (recommended value = ${RECOMMENDED_VAL//$'\t'/,} // current value = ${CURRENT_VAL//$'\t'/,}). $PARAM: $MESSAGE" >> "$MESSAGES_FILE"

		echo "kernel_$PARAM=\"${RECOMMENDED_VAL//$'\t'/,}\"" >> "$STATUS_FILE"	# Save the current value

		[[ $(_CHECK_PROFILE_FILE_FUNCTION "$TYPE" action) == 1 ]]  && echo "sysctl -w $PARAM $RECOMMENDED_VAL" >> "$KERNEL_ACTIONS_FILE"	# Save action
	done
}

_CHECK_MODULE_BLACKLISTING_FUNCTION()	{
	local MODULE_BLACKLIST_FILE
	local MODULES_FILE
	MODULES_FILE="$MAIN_DIR/resources/kernel-blocked-modules.rc"
	MODULE_BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"

	source "$MODULES_FILE"

	if [[ $(_CHECK_PROFILE_FILE_FUNCTION module action) == 1 ]]; then
		[[ ! -f $MODULE_BLACKLIST_FILE ]] && touch $MODULE_BLACKLIST_FILE
	fi

	for TYPE in $MOD_TYPES; do
		if [[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" check) == 1 ]]
		then
			for MODULE in ${!TYPE}; do
				grep -q "$MODULE" "$MODULE_BLACKLIST_FILE" && continue
				echo "kernel_module_$MODULE=0" >> "$STATUS_FILE"
				echo "Kernel-Module-Hardening[$MODULE]: Kernel module $MODULE is recommended to be blacklisted, because either it has a history of vulnerabilities, or it's weak." >> "$MESSAGES_FILE"

				lsmod | grep -q "$MODULE" && echo "Kernel-Hardening[$MODULE]: Kernel module $MODULE is loaded on you currently running system, but it's dangerous for security reasons." >> "$MESSAGES_FILE"
				[[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
			done
		fi
	done
}

[[ $(_CHECK_PROFILE_FILE_FUNCTION check) == 1 ]] && _CHECK_PARAM_FUNCTION
[[ $(_CHECK_PROFILE_FILE_FUNCTION module check) == 1 ]] && _CHECK_MODULE_BLACKLISTING_FUNCTION

[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 1 ]] && echo "$KERNEL_ACTIONS_FILE" >> "$ACTIONS_FILE"	# Add approved actions to the actions file

echo ""
echo "Kernel Hardening script has finished"
echo ""
