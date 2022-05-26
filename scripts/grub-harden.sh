#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# GRUB Boot Parameters hardening

usage() {
	echo "Usage: $0 -md/--main-directory [main directory] -pf/--profile-file [profile file] \
-st/--status-file [status file] -mf/--messages-file [messages file] -af/--actions-file [actions file]";
}

RUNTIME_DATE=$(date +%F_%H-%M-%S)	# Runtime date and time

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
		-sf|--status-file)
			STATUS_FILE=$2
			shift 2
			;;
		-mf|--messages-file)
			MESSAGES_FILE=$2
			shift 2
			;;
		-af|--actions-file)
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

STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/grub.status"}	# Currently used status file
GRUB_ACTIONS_FILE="$MAIN_DIR/scripts/grub-actions.sh"
GRUB_FILE="/etc/default/grub"

echo ""
echo "GRUB Hardening script has started..."
echo ""

source "$MAIN_DIR/resources/grub-parameters.rc"

# Queue the requested value from the JSON profile file by jq
check-pf()  {
	PF_VALUE="$*"
	jq '.[] | select(.name=="grub")' "$PROFILE_FILE" | jq ".grub.${PF_VALUE// /.}"
}

# Prepare the GRUB_ACTIONS_FILE
[[ $(check-pf general action) == 1 ]] && echo "\
#!/usr/bin/env bash

OLD_FILE='/etc/default/grub'

GRUB_ACTION=''
" >> $GRUB_ACTIONS_FILE

check-param()	{
	local CURRENT
	local CPU_MIT
	local CPU_MIT_MISSED

	CURRENT=$(grep "$1" "$GRUB_FILE")
	CURRENT=${CURRENT##"$1"}	# Substitute string to get only the CMDLINE parameters
	CURRENT=${CURRENT//\"/}

	if [[ $(check-pf general check) == 1 ]]
	then
		# Loop through all general recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_OPTIONS; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array
			echo "GRUB_$PARAM=0" >> "$STATUS_FILE"
			P=${PARAM//=/_}
			P=${P//./_}
			echo "GRUB-Hardening[$PARAM]: $PARAM option is recommended for grub in GRUB_CMDLINE_LINUX_DEFAULT variable in /etc/default/grub." >> "$MESSAGES_FILE"
			echo "$PARAM: ${!P}" >> "$MESSAGES_FILE"

			[[ $(check-pf general action) == 1 ]] && echo "GRUB_ACTION=\"\$GRUB_ACTION $PARAM\"" >> "$GRUB_ACTIONS_FILE"
		done
	fi

	CPU_MIT=1
	CPU_MIT_MISSED=""
	if [[ $(check-pf cpu_metigations check) == 1 ]]
	then
		# Loop through all cpu mitigations recommended values and check if they are applied, then save recommeneded action if required
		for PARAM in $GRUB_CPU_MIT; do
			[[ $CURRENT =~ $PARAM ]] && continue	# Check if recommended parameter is in the current values array

			CPU_MIT=0
			CPU_MIT_MISSED="$CPU_MIT_MISSED $PARAM"
			echo "GRUB_$PARAM=0" >> "$STATUS_FILE"

			[[ $(check-pf cpu_metigations action) == 0 ]] && continue
			echo "GRUB_ACTION=\"\$GRUB_ACTION $PARAM\"" >> "$GRUB_ACTIONS_FILE"
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
		echo ""
		echo "cp /etc/default/grub /etc/default/grub.old.$RUNTIME_DATE"
		echo "echo \"\" > /etc/default/grub"
		echo "cat /etc/default/grub.old | while read line; do"
		echo "	if [[ \$line =~ \"GRUB_CMDLINE_LINUX=\" ]]"
		echo "then"
		echo "		line=\"\${line##\"GRUB_CMDLINE_LINUX=\"}\"	# Substitute string to get only the CMDLINE parameters"
		echo "		line=\"\${line#\\\"}\""
		echo "		line=\"\${line%\\\"}\""
		echo "		echo \"GRUB_CMDLINE_LINUX=\"\$line \$GRUB_ACTION\"\" >> /etc/default/grub"
		echo ""
		echo "	elif [[ \$line =~ \"GRUB_CMDLINE_LINUX_DEFAULT=\" ]] then"
		echo "		line=\${line##\"GRUB_CMDLINE_LINUX_DEFAULT=\"}	# Substitute string to get only the CMDLINE parameters"
		echo "		line=\${line#\\\"}"
		echo "		line=\${line%\\\"}"
		echo "		echo \"GRUB_CMDLINE_LINUX_DEFAULT=\"\$line \${GRUB_ACTION[@]}\"\" >> /etc/default/grub"
		echo ""
		echo "	else"
		echo "		echo \$line >> /etc/default/grub"
		echo "	fi"
		echo "done"
		echo ""
	} >> "$GRUB_ACTIONS_FILE"
}

if [[ $(check-pf check) == 1 ]]
then
	grep -q "GRUB_CMDLINE_LINUX=" "$GRUB_FILE" && check-param "GRUB_CMDLINE_LINUX="
	grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" && check-param "GRUB_CMDLINE_LINUX_DEFAULT="
fi

[[ $(check-pf action) == 1 ]] && write-to-actions-file && echo "$GRUB_ACTIONS_FILE" >> "$ACTIONS_FILE"

echo ""
echo "GRUB Hardening script has finished"
echo ""
