#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# GRUB Boot Parameters hardening


[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
GRUB Hardening is starting up as pid=$$  at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

declare -r STATUS_FILE="$STATUS_DIR/grub-harden.status"	GRUB_ACTIONS_FILE="$ACTIONS_DIR/grub-actions.sh"

echo "GRUB Hardening script has started..."

GRUB_ACTION=""

GRUB_FILE="/etc/default/grub"
[[ ! -e $GRUB_FILE ]] && {
	echo >&2 "$0: Alert!! The GRUB2 default profile file $GRUB_FILE couldn't be found."
	echo >&2 "Can not continue, quitting..."
	exit 1
}

[[ ! -e "$RESOURCES_DIR/grub-parameters.rc" ]] && {
	echo >&2 "$0: Alert!! Kernel hardening resources file doesn't exist '$RESOURCES_DIR/grub-parameters.rc'"
	echo >&2 "Can not continue executing without it."
	echo >&2 "if you don't know what caused this, reinstall the service package and everything will be fine."
	echo >&2 "Quiting..."
	exit 1
}
source "$RESOURCES_DIR/grub-parameters.rc"

_check_param_function()	{
	local CURRENT CPU_MIT_MISSED

	# $1 would be either GRUB_CMDLINE_LINUX_DEFAULT or GRUB_CMDLINE_LINUX
	CURRENT=$(grep "$1" "$GRUB_FILE")
	CURRENT=${CURRENT##"$1"}	# Substitute string to get only the CMDLINE parameters
	CURRENT=${CURRENT//\"/}

	if [[ $(_check_profile_file_function grub general check) == 1 ]]; then
		# Loop through all general recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_OPTIONS; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array
			P=${PARAM//=/_}
			P=${P//./_}
			echo "GRUB_$P=1" >> "$STATUS_FILE"
			echo "GRUB General [$PARAM] : $PARAM option is recommended for grub in GRUB_CMDLINE_LINUX_DEFAULT variable in /etc/default/grub. $PARAM: ${!P}" >> "$MESSAGES_FILE"

			GRUB_ACTION="$GRUB_ACTION $PARAM"
		done
	fi

	declare -i CPU_MIT=1
	CPU_MIT_MISSED=""
	if [[ $(_check_profile_file_function grub cpu_metigations check) == 1 ]]; then
		# Loop through all cpu mitigations recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_CPU_MIT; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array

			CPU_MIT=0
			CPU_MIT_MISSED="$CPU_MIT_MISSED $PARAM"

			P=${PARAM//=/_}
			P=${P//./_}
			echo "GRUB_$P=1" >> "$STATUS_FILE"

			GRUB_ACTION="$GRUB_ACTION $PARAM"
		done

		if [[ $CPU_MIT == 0 ]]; then
		{
			echo "GRUB CPU_Mitigations : These recommended CPU mitigations are not applied: $CPU_MIT_MISSED."
			echo "GRUB CPU_Mitigations : $GRUB_CPU_MIT_MESSAGE"
		} >> "$MESSAGES_FILE"
		fi
	fi
}

_write_to_actions_file()	{
	{
		echo '#!/usr/bin/env bash'
		echo ''
		echo 'RUNTIME_DATE=$(date "+%s_%F")	# Runtime date and time'
		echo 'OLD_FILE="/etc/default/grub.old.$RUNTIME_DATE"'
		echo ''
		echo 'cp /etc/default/grub "$OLD_FILE"'
		echo 'echo "" > /etc/default/grub'
		echo ''
		echo 'while read -r line; do'
		echo '	if [[ $line =~ ^GRUB_CMDLINE_LINUX= ]]; then'
		echo '		line="${line##GRUB_CMDLINE_LINUX=}"	# Substitute string to get only the CMDLINE parameters'
		echo '		line="${line//\"/}"'
#		echo "		line=\"\${line#\\\"}\""
#		echo "		line=\"\${line%\\\"}\""
		echo "		echo \"GRUB_CMDLINE_LINUX=\\\"\$line $GRUB_ACTION\\\"\" >> /etc/default/grub"
		echo ""
		echo '	elif [[ $line =~ ^GRUB_CMDLINE_LINUX_DEFAULT= ]]; then'
		echo '		line="${line##GRUB_CMDLINE_LINUX_DEFAULT=}"	# Substitute string to get only the CMDLINE parameters'
		echo '		line="${line//\"/}"'
#		echo "		line=\${line#\\\"}"
#		echo "		line=\${line%\\\"}"
		echo "		echo \"GRUB_CMDLINE_LINUX_DEFAULT=\\\"\$line $GRUB_ACTION\\\"\" >> /etc/default/grub"
		echo ""
		echo '	else'
		echo '		echo "$line" >> /etc/default/grub'
		echo '	fi'
		echo 'done < "$OLD_FILE"'
		echo ""
		echo 'grub2-mkconfig -o /boot/grub2/grub.cfg'
	} > "$GRUB_ACTIONS_FILE"
}

if [[ $(_check_profile_file_function grub check) == 1 ]]
then
	grep -q "GRUB_CMDLINE_LINUX=" "$GRUB_FILE" 2>/dev/null && _check_param_function "GRUB_CMDLINE_LINUX="
	grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" 2>/dev/null && _check_param_function "GRUB_CMDLINE_LINUX_DEFAULT="
fi

if [[ $(_check_profile_file_function grub action) == 1 ]] && [[ -n $GRUB_ACTION ]];then
	_write_to_actions_file && echo "$GRUB_ACTIONS_FILE" >> "$ACTIONS_FILE"
fi

echo ""
echo "GRUB Hardening script has finished"
echo ""
