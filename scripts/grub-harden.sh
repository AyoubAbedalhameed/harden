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
Harden service is starting up ...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/grub-harden.status"}	# Currently used status file

GRUB_ACTIONS_FILE="$MAIN_DIR/actions/grub-actions.sh"

# Queue the requested value from the JSON profile file by jq
_CHECK_PROFILE_FILE_FUNCTION()  {
	PF_VALUE="$*"
	jq '.[] | select(.name=="grub")' "$PROFILE_FILE" | jq ".grub.${PF_VALUE// /.}"
}

echo ""
echo "GRUB Hardening script has started..."
echo ""

GRUB_ACTION=""

GRUB_FILE="/etc/default/grub"
[[ ! -e $GRUB_FILE ]] && {
	echo >&2 "$0: GRUB default profile file $GRUB_FILE doean't exist."
	exit 1
}

[[ ! -e "$MAIN_DIR/resources/grub-parameters.rc" ]] && {
	echo >&2 "$0: Grub hardening resources file doesn't exist '$MAIN_DIR/resources/grub-parameters.rc', please run the script in it's original place, or check you installation."
	exit 1
}
source "$MAIN_DIR/resources/grub-parameters.rc"

_CHECK_PARAM()	{
	local CURRENT
	local CPU_MIT
	local CPU_MIT_MISSED

	# $1 would be either GRUB_CMDLINE_LINUX_DEFAULT or GRUB_CMDLINE_LINUX
	CURRENT=$(grep "$1" "$GRUB_FILE")
	CURRENT=${CURRENT##"$1"}	# Substitute string to get only the CMDLINE parameters
	CURRENT=${CURRENT//\"/}

	if [[ $(_CHECK_PROFILE_FILE_FUNCTION general check) == 1 ]]
	then
		# Loop through all general recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_OPTIONS; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array
			echo "GRUB_$PARAM=0" >> "$STATUS_FILE"
			P=${PARAM//=/_}
			P=${P//./_}
			echo "GRUB-Hardening[$PARAM]: $PARAM option is recommended for grub in GRUB_CMDLINE_LINUX_DEFAULT variable in /etc/default/grub. $PARAM: ${!P}" >> "$MESSAGES_FILE"

			GRUB_ACTION="$GRUB_ACTION $PARAM"
		done
	fi

	CPU_MIT=1
	CPU_MIT_MISSED=""
	if [[ $(_CHECK_PROFILE_FILE_FUNCTION cpu_metigations check) == 1 ]]
	then
		# Loop through all cpu mitigations recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_CPU_MIT; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array

			CPU_MIT=0
			CPU_MIT_MISSED="$CPU_MIT_MISSED $PARAM"
			echo "GRUB_$PARAM=0" >> "$STATUS_FILE"

			GRUB_ACTION="$GRUB_ACTION $PARAM"
		done

		if [[ $CPU_MIT == 0 ]] 
		then
		{
			echo "GRUB-Hardening[$PARAM]: These recommended CPU mitigations are not applied:"
			echo "$CPU_MIT_MISSED"
			echo "$GRUB_CPU_MIT_MESSAGE"
		} >> "$MESSAGES_FILE"
		fi
	fi
}

write-to-actions-file()	{
	{
		echo "#!/usr/bin/env bash"
		echo ""
		echo "OLD_FILE='/etc/default/grub'"
		echo ""
		echo "cp /etc/default/grub /etc/default/grub.old.$RUNTIME_DATE"
		echo "echo \"\" > /etc/default/grub"
		echo "cat /etc/default/grub.old | while read line; do"
		echo "	if [[ \$line =~ \"GRUB_CMDLINE_LINUX=\" ]]"
		echo "then"
		echo "		line=\"\${line##\"GRUB_CMDLINE_LINUX=\"}\"	# Substitute string to get only the CMDLINE parameters"
		echo "		line=\"\${line#\\\"}\""
		echo "		line=\"\${line%\\\"}\""
		echo "		echo \"GRUB_CMDLINE_LINUX=\"\$line $GRUB_ACTION\"\" >> /etc/default/grub"
		echo ""
		echo "	elif [[ \$line =~ \"GRUB_CMDLINE_LINUX_DEFAULT=\" ]] then"
		echo "		line=\${line##\"GRUB_CMDLINE_LINUX_DEFAULT=\"}	# Substitute string to get only the CMDLINE parameters"
		echo "		line=\${line#\\\"}"
		echo "		line=\${line%\\\"}"
		echo "		echo \"GRUB_CMDLINE_LINUX_DEFAULT=\"\$line $GRUB_ACTION\"\" >> /etc/default/grub"
		echo ""
		echo "	else"
		echo "		echo \$line >> /etc/default/grub"
		echo "	fi"
		echo "done"
		echo ""
	} > "$GRUB_ACTIONS_FILE"
}

if [[ $(_CHECK_PROFILE_FILE_FUNCTION check) == 1 ]]
then
	grep -q "GRUB_CMDLINE_LINUX=" "$GRUB_FILE" 2>/dev/null && _CHECK_PARAM "GRUB_CMDLINE_LINUX="
	grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" 2>/dev/null && _CHECK_PARAM "GRUB_CMDLINE_LINUX_DEFAULT="
fi

[[ $(_CHECK_PROFILE_FILE_FUNCTION action) == 1 ]] && write-to-actions-file && echo "$GRUB_ACTIONS_FILE" >> "$ACTIONS_FILE"

echo ""
echo "GRUB Hardening script has finished"
echo ""
