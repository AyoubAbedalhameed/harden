#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# GRUB Boot Parameters hardening

_USAGE_FUNCTION() {
	echo >&2 "Usage: $0 -md [main directory] -pf [profile file] -st [status file] -mf [messages file] -af [actions file]";
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
			if [[ ! -e $2 ]]; then echo >&2 "$0: Invalid input for profile file (-pf) $PROFILE_FILE, file doesn't exist. Going to use the default ones (/etc/harden/profile-file.json or /usr/share/harden/config/profile-file.json)"
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

MAIN_DIR=$(pwd)
MAIN_DIR=${MAIN_DIR%/scripts}

if [[ ! -e $PROFILE_FILE ]]; then
	if [[ -e /etc/harden/profile-file.json ]]; then
		PROFILE_FILE="etc/harden/profile-file.json"	# Use Default User Choice Profile File,
	elif [[ -e $MAIN_DIR/config/profile-file.json ]]; then
		PROFILE_FILE="$MAIN_DIR/config/profile-file.json"	# if not set by a positional parameter (command line argument)
	else
		echo >&2 "$0: Critical Error: JSON file \"profile-file.json\" which is the main congifuration file for the Linux Hardening Project, is missing. \
Couldn't find it in: $PROFILE_FILE, or /etc/harden/profile-file.json, or /usr/share/harden/config/profile-file.json"
		exit 1
	fi

	echo >&2 "$0: Using $PROFILE_FILE for the current run as profile-file."
fi

MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/grub-harden_$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/grub-harden_$RUNTIME_DATE.sh"}	# Currently used Actions file
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
