#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
Kernel Hardening is starting up as pid=$$ at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

declare -r STATUS_FILE="$STATUS_DIR/kernel-harden.status"	# Currently used status file
declare -r KERNEL_ACTIONS_FILE="$ACTIONS_DIR/kernel-actions.sh"

echo ""
echo "Kernel Hardening script has started..."

# Check for the existence of the resources file, if not then print an error message and exit
declare -r PARAMETERS_FILE="$RESOURCES_DIR/kernel-parameters.rc" MODULES_FILE="$RESOURCES_DIR/kernel-blocked-modules.rc"

if [[ ! -e "$PARAMETERS_FILE" ]] || [[ ! -e "$MODULES_FILE" ]]; then
	echo >&2 "$0: Alert!! Kernel hardening resources files doesn't exist '$PARAMETERS_FILE' '$MODULES_FILE'"
	echo >&2 "Can not continue executing without it."
	echo >&2 "if you don't know what caused this, reinstall the service package and everything will be fine."
	echo >&2 "Quiting..."
	exit 1
fi


_check_param_function()	{
	source "$PARAMETERS_FILE"

	# Declare these variables with integer and readonly attributes to prevent mistakes
	declare -ri VAL_INDEX=0 MES_INDEX=1 TYPE_INDEX=2

	# 'sed' here is used to extract only the dictionary keys that ends with ',0', so we loop only once on each parameter once
	for PARAM in $(echo "${!kernel[@]}" | sed 's/[a-z\0-9\.\_\-]*,[1-2]//g'); do
		PARAM="${PARAM%,*}"	# Substring from the begging to the comma (,) to get the parameter name without the index
		MESSAGE="${kernel[$PARAM,$MES_INDEX]}"
		TYPE="${kernel[$PARAM,$TYPE_INDEX]}"
		RECOMMENDED_VAL="${kernel[$PARAM,$VAL_INDEX]}"
		RECOMMENDED_VAL="${RECOMMENDED_VAL//,/$'\t'}"	# Replace commas (,) with tabs (\t), if exists

		[[ $(_check_profile_file_function kernel "$TYPE" check) != 1 ]]  && continue	# Skip checking this parameter if profile file says so
		CURRENT_VAL="$(sysctl -en "$PARAM")"
		CURRENT_VAL="${CURRENT_VAL//$'\t'/,}"

		[[ -z "$CURRENT_VAL" ]]   && continue

		# Compare current value with recommended one
		[[ "$CURRENT_VAL" == "$RECOMMENDED_VAL" ]] && continue
		# Print Message
		echo "Kernel-Parameter-Hardening[$PARAM]: (recommended value = ${RECOMMENDED_VAL//$'\t'/,} // current value = ${CURRENT_VAL//$'\t'/,}). $MESSAGE" >> "$MESSAGES_FILE"

		P=${PARAM//./_}
		P=${P//-/_}
		echo "kernel_parameter_$P=\"$CURRENT_VAL\"" >> "$STATUS_FILE"	# Save the current value

		[[ $(_check_profile_file_function kernel "$TYPE" action) == 1 ]]  && echo "sysctl -w $PARAM $RECOMMENDED_VAL" >> "$KERNEL_ACTIONS_FILE"	# Save action
	done
}

_check_module_blacklisting_function()	{
	declare -r MODULE_BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"
	RUNNING_MODULES=$(lsmod | awk '{print $1;}')

	source "$MODULES_FILE"

	if [[ ! -f $MODULE_BLACKLIST_FILE ]]; then
		[[ $(_check_profile_file_function kernel action) == 1 ]] && echo "touch $MODULE_BLACKLIST_FILE" >> "$KERNEL_ACTIONS_FILE"
		echo "Kernel-Module-Hardening: Your system doesn't have any modules blocked in $MODULE_BLACKLIST_FILE (it doesn't even exist)" >> $MESSAGES_FILE

		for TYPE in $MOD_TYPES; do
			if [[ $(_check_profile_file_function kernel module "$TYPE" check) == 1 ]]
			then
				for MODULE in ${!TYPE}; do
					[[ ! $RUNNING_MODULES =~ (^|[[:space:]])"$MODULE"($|[[:space:]]) ]] && continue
					echo "kernel_module_$MODULE=1" >> "$STATUS_FILE"
					echo "Kernel-Module-Hardening[$MODULE]: Kernel module $MODULE currently loaded and running on your system, it is recommended to be blacklisted, \
because either it has a history of vulnerabilities, or it's weak." >> "$MESSAGES_FILE"

					[[ $(_check_profile_file_function kernel module "$TYPE" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
				done
			fi
		done

	else 
		for TYPE in $MOD_TYPES; do
			if [[ $(_check_profile_file_function kernel module "$TYPE" check) == 1 ]]
			then
				for MODULE in ${!TYPE}; do
					[[ $RUNNING_MODULES =~ (^|[[:space:]])"$MODULE"($|[[:space:]]) ]] && echo "Kernel-Hardening[$MODULE]: Warning!! Kernel module $MODULE is loaded on you currently \
running system, but it's dangerous for security reasons." >> "$MESSAGES_FILE"

					grep -q "$MODULE" "$MODULE_BLACKLIST_FILE" && continue

					echo "kernel_module_$MODULE=1" >> "$STATUS_FILE"
					echo "Kernel-Module-Hardening[$MODULE]: Kernel module $MODULE is recommended to be blacklisted, because either it has a history of vulnerabilities, \
or it's weak." >> "$MESSAGES_FILE"

					[[ $(_check_profile_file_function kernel module "$TYPE" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
				done
			fi
		done
	fi
}

[[ $(_check_profile_file_function kernel check) == 1 ]] && _check_param_function
[[ $(_check_profile_file_function kernel module check) == 1 ]] && _check_module_blacklisting_function

[[ $(_check_profile_file_function kernel action) == 1 ]] && echo "$KERNEL_ACTIONS_FILE" >> "$ACTIONS_FILE"	# Add approved actions to the actions file

echo ""
echo "Kernel Hardening script has finished"
echo ""
