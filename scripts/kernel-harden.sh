#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
Harden service is starting up ...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

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
	local RUNNING_MODULES
	MODULES_FILE="$MAIN_DIR/resources/kernel-blocked-modules.rc"
	MODULE_BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"
	RUNNING_MODULES=$(lsmod | awk '{print $1;}')

	source "$MODULES_FILE"

	[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 1 ]] && touch $MODULE_BLACKLIST_FILE

	if [[ ! -f $MODULE_BLACKLIST_FILE ]]; then
		echo "Your system doesn't have any modules blocked in $MODULE_BLACKLIST_FILE (it doesn't even exist)" >> $MESSAGES_FILE
		for TYPE in $MOD_TYPES; do
			if [[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" check) == 1 ]]
			then
				for MODULE in ${!TYPE}; do
					[[ ! $RUNNING_MODULES =~ $MODULE ]] && continue
					echo "kernel_module_$MODULE=0" >> "$STATUS_FILE"
					echo "Kernel-Module-Hardening[$MODULE]: Kernel module $MODULE currently loaded and running on your system, it is recommended to be blacklisted, because either it has a history of vulnerabilities, or it's weak." >> "$MESSAGES_FILE"

					[[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
				done
			fi
		done

	else 
		for TYPE in $MOD_TYPES; do
			if [[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" check) == 1 ]]
			then
				for MODULE in ${!TYPE}; do
					grep -q "$MODULE" "$MODULE_BLACKLIST_FILE" && continue
					echo "kernel_module_$MODULE=0" >> "$STATUS_FILE"
					echo "Kernel-Module-Hardening[$MODULE]: Kernel module $MODULE is recommended to be blacklisted, because either it has a history of vulnerabilities, or it's weak." >> "$MESSAGES_FILE"

					[[ ! $RUNNING_MODULES =~ $MODULE ]] && echo "Kernel-Hardening[$MODULE]: Kernel module $MODULE is loaded on you currently running system, but it's dangerous for security reasons." >> "$MESSAGES_FILE"
					[[ $(_CHECK_PROFILE_FILE_FUNCTION module "$TYPE" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
				done
			fi
		done
	fi
}

[[ $(_CHECK_PROFILE_FILE_FUNCTION check) == 1 ]] && _CHECK_PARAM_FUNCTION
[[ $(_CHECK_PROFILE_FILE_FUNCTION module check) == 1 ]] && _CHECK_MODULE_BLACKLISTING_FUNCTION

[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 1 ]] && echo "$KERNEL_ACTIONS_FILE" >> "$ACTIONS_FILE"	# Add approved actions to the actions file

echo ""
echo "Kernel Hardening script has finished"
echo ""
