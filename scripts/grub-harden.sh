#!/usr/bin/env bash
# Written by: Adnan Omar (aalkhaldi8@gmail.com)

# GRUB Boot Parameters hardening

usage() {   echo "Usage: $0 -md/--main-directory [main directory] -pf/--profile-file [profile file] \
-st/--status-file [status file] -mf/--messages-file [messages file] -af/--actions-file [actions file]"; }

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
		-sf|--status-file)	# Use a configuration file from user choice
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
PROFILE_FILE=${PROFILE_FILE:="/etc/harden/default.profile"}	# Use Default User Choice Profile File,
										# if not set by a positional parameter (command line argument)
STATUS_FILE=${STATUS_FILE:="$MAIN_DIR/status/$RUNTIME_DATE.status"}	# Currently used status file
MESSAGES_FILE=${MESSAGES_FILE:="$MAIN_DIR/messages/$RUNTIME_DATE.message"}	# Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$MAIN_DIR/actions/$RUNTIME_DATE.sh"}	# Currently used Actions file

GRUB_ACTIONS_FILE="$MAIN_DIR/scripts/grub-actions.sh"
GRUB_FILE="/etc/default/grub"

RESOURSES_FILE="$MAIN_DIR/resources/grub-parameters.rc"
source $RESOURSES_FILE

# Queue the requested value from the JSON profile file by jq
PROFILE=$(jq '.[] | select(.name=="grub")' $PROFILE_FILE)	# Save our object from the array
check-pf()  {   return $(echo $PROFILE | jq ".grub.$1.$2");  }

# Prepare the GRUB_ACTIONS_FILE
[[ $(check-pf general action) == 0 ]] && echo "\
#!/usr/bin/env bash

OLD_FILE='/etc/default/grub'

GRUB_ACTION=()
" >> $GRUB_ACTIONS_FILE

check-param()	{
	CURRENT=$(grep $1 $GRUB_FILE)
	CURRENT=${CURRENT##$1}	# Substitute string to get only the CMDLINE parameters
	CURRENT=${CURRENT#\"}
	CURRENT=${CURRENT%\"}
	CURRENT=($CURRENT)	# Convert string to an array

	# Loop through all general recommended values and check if they are applied, then save recommeneded action if required
	for PARAM in "${!GRUB[@]}"; do
		[[ $(check-pf general check) == 0 ]] && continue
		[[ "${CURRENT[*]}" =~ (^|[[:space:]])"$PARAM"($|[[:space:]]) ]] && continue	# Check if recommended parameter is in the current values array

		echo "GRUB-Hardening($PARAM) 0" >> STATUS_FILE
		echo "GRUB-Hardening[$PARAM]: ${grub[$PARAM]}" >> $MESSAGES_FILE

		[[ $(check-pf general action) == 0 ]] && continue
		echo "GRUB_ACTION+=($PARAM)" >> $GRUB_ACTIONS_FILE
	done

	CPU_MIT=1
	CPU_MET_MISSED=()
	# Loop through all cpu mitigations recommended values and check if they are applied, then save recommeneded action if required
	for PARAM in "${GRUB_CPU_MIT_MESSAGE[@]}"; do
		[[ $(check-pf cpu_metigations check) == 0 ]] && continue
		[[ "${CURRENT[*]}" =~ (^|[[:space:]])"$PARAM"($|[[:space:]]) ]] && continue	# Check if recommended parameter is in the current values array

		CPU_MIT=0
		CPU_MIT_MISSED+=($PARAM)
		echo "GRUB-Hardening($PARAM) 0" >> STATUS_FILE

		[[ $(check-pf cpu_metigations action) == 0 ]] && continue
		echo "GRUB_ACTION+=($PARAM)" >> $GRUB_ACTIONS_FILE
	done

	if [[ $CPU_MIT == 0 ]] then
		echo "GRUB-Hardening[$PARAM]: These recommended CPU mitigations are not applied:
${CPU_MIT_MISSED[@]}
$GRUB_CPU_MIT_MESSAGE" >> $MESSAGES_FILE
	fi
}

grep -q "GRUB_CMDLINE_LINUX=" "$GRUB_FILE" && check-param "GRUB_CMDLINE_LINUX="
grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" && check-param "GRUB_CMDLINE_LINUX_DEFAULT="

[[ $(check-pf general action) == 0 ]] && echo"\
cp /etc/default/grub /etc/default/grub.old.$RUNTIME_DATE
echo "" > /etc/default/grub
cat /etc/default/grub.old | while read line; do
	if [[ $line =~ "GRUB_CMDLINE_LINUX=" ]] then
		line=${line##"GRUB_CMDLINE_LINUX="}	# Substitute string to get only the CMDLINE parameters
		line=${line#\"}
		line=${line%\"}
		echo "GRUB_CMDLINE_LINUX=\"$line ${GRUB_ACTION[@]}\"" >> /etc/default/grub

	elif [[ $line =~ "GRUB_CMDLINE_LINUX_DEFAULT=" ]] then
		line=${line##"GRUB_CMDLINE_LINUX_DEFAULT="}	# Substitute string to get only the CMDLINE parameters
		line=${line#\"}
		line=${line%\"}
		echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$line ${GRUB_ACTION[@]}\"" >> /etc/default/grub

	else
		echo $line >> /etc/default/grub
	fi
done
" >> $GRUB_ACTIONS_FILE

echo $GRUB_ACTIONS_FILE >> $ACTIONS_FILE
