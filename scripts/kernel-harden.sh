#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

usage() {
	echo "Usage: $0 -md/--main-directory [main directory] -pf/--profile-file [profile file] \
-mf/--messages-file [messages file] -af/--actions-file [actions file]";
}

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
PROFILE_FILE=${PROFILE_FILE:="/etc/harden/profile-file.json"}	# Use Default User Choice Profile File,
								# if not set by a positional parameter (command line argument)
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file

STATUS_FILE="$MAIN_DIR/status/kernel.status"	# Currently used status file
PARAMETERS_FILE="$MAIN_DIR/resources/kernel-parametrs.rc"
KERNEL_ACTIONS_FILE="$MAIN_DIR/actions/kernel-actions.sh"

# Queue the requested value from the JSON profile file by jq
PROFILE=$(jq '.[] | select(.name=="kernel")' "$PROFILE_FILE")	# Save our object from the array
check-pf()  {
	return "$(echo $PROFILE | jq ".kernel.$1.$2")"
}

[[ $(check-pf check) == 0 ]] && exit

check-param()	{
	source "$PARAMETERS_FILE"

	VAL_INDEX=0
	MES_INDEX=1
	TYPE_INDEX=2

	# 'sed' here is used to extract only the dictionary keys that ends with ',0', so we loop only once on each parameter once
	for PARAM in $(echo "${!kernel[@]}" | sed 's/[a-z\0-9\.\_\-]*,[1-2]//g'); do
		PARAM=${PARAM%,*}	# Substring from the begging to the comma (,) to get the parameter name without the index
		MESSAGE="${kernel[$PARAM,$MES_INDEX]}"
		TYPE="${kernel[$PARAM,$TYPE_INDEX]}"
		RECOMMENDED_VAL="${kernel[$PARAM,$VAL_INDEX]}"
		RECOMMENDED_VAL=${RECOMMENDED_VAL//,/$'\t'}	# Replace commas (,) with tabs (\t), if exists

		[[ $(check-pf "$TYPE" check) == 0 ]]  && continue	# Skip checking this parameter if profile file says so
		CURRENT_VAL=$(sysctl -en "$PARAM")
		CURRENT_VAL=${CURRENT_VAL//$'\t'/,}

		[[ -z "$CURRENT_VAL" ]]   && continue

		# Compare current value with recommended one
		[[ "$CURRENT_VAL" != "$RECOMMENDED_VAL" ]] && echo "Kernel-Hardening[$PARAM]: Kernel Parameter $PARAM recommended value is \
	${RECOMMENDED_VAL//$'\t'/,}, but the current value is ${CURRENT_VAL//$'\t'/,}. $MESSAGE" >> "$MESSAGES_FILE"	# Print Message

		echo "kernel_$PARAM=\"${RECOMMENDED_VAL//$'\t'/,}\"" >> "$STATUS_FILE"	# Save the current value

		[[ $(check-pf "$TYPE" action) == 0 ]]  && continue	# Skip actions for this parameter if profile file says so
		echo "sysctl -w $PARAM $RECOMMENDED_VAL" >> "$KERNEL_ACTIONS_FILE"	# Save action
	done
}

module-blacklist()	{
	source "../resources/kernel-blocked-modules.rc"

	MODULE_BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"
	[[ $(check-pf module action) ]] && [[ ! -f $MODULE_BLACKLIST_FILE ]] && touch $MODULE_BLACKLIST_FILE
	for MODULE in "${!MODULE_BLACKLIST[@]}"; do
		[[ $(check-pf module "${MODULE_BLACKLIST[$MODULE]}" check) == 0 ]] && continue

		grep -q "$MODULE" "$MODULE_BLACKLIST_FILE" && continue
		echo "kernel_module_$MODULE=0" >> "$STATUS_FILE"
		echo "Kernel-Hardening[$MODULE]: Kernel module $MODULE is recommended to be blacklisted, because it has a history of vulnerabilities." >> "$MESSAGES_FILE"

		lsmod | grep -q "$MODULE" && echo "Kernel-Hardening[$MODULE]: Kernel module $MODULE is loaded on you currently running system, but it's dangerous for security reasons." >> "$MESSAGES_FILE"
		[[ $(check-pf module "${MODULE_BLACKLIST[$MODULE]}" action) == 1 ]] && echo "echo \"blacklist $MODULE\" >> $MODULE_BLACKLIST_FILE" >> "$ACTIONS_FILE"
	done
}

[[ $(check-pf module check) == 1 ]] && module-blacklist

[[ $(check-pf action) == 1 ]] && echo "$KERNEL_ACTIONS_FILE" >> "$ACTIONS_FILE"	# Add approved actions to the actions file
