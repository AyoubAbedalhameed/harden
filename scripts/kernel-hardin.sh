#!/usr/bin/bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

CONFIG_FILE="/usr/share/harden/config/kernel-parametrs.rc"
KERNEL_ACTIONS_FILE="/usr/share/config/$(date +%F_%H:%M:%S)_kernel-actions.sh"

# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
    case $1 in
        -pf|--profile-file)
            PROFILE_FILE=$2
            shift 2
            ;;
        -sf|--status-file)  # Use a configuration file from user choice
            STATUS_FILE=$2
            shift 2
            ;;
        -mf|--messages-file)    # Use/Create a messages file from user choice
            MESSAGES_FILE=$2
            shift 2 # shift the arguments 2 times (we used two arguments)
            ;;
        -af|--actions-file) # Use/Create an actions file from user choice
            ACTIONS_FILE=$2
            shift 2
            ;;
        -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arguments
            shift
            ;;
    esac
done

# Restore Positional Arguments (those which has not been used)
set -- "${POSITIONAL_ARGS[@]}"

check-pf()  {
    return $(jq ".kernel.$1.$2" $PROFILE_FILE)
}

. $CONFIG_FILE

VAL_INDEX=0
MES_INDEX=1
TYPE_INDEX=2

for PARAM in "${!kernel[@]}"; do
    PARAM=${PARAM%,*}   # Substring from the begging to the comma (,) to get the parameter name without the index
    MESSAGE="${kernel[$PARAM,$MES_INDEX]}"
    TYPE="${kernel[$PARAM,$TYPE_INDEX]}"
    RECOMMENDED_VAL="${kernel[$PARAM,$VAL_INDEX]}"
    RECOMMENDED_VAL=${RECOMMENDED_VAL//,/$'\t'}     # Replace commas (,) with tabs (\t), if exists

    [[ $(check-pf $TYPE check) == 0 ]]  && continue     # Skip checking this parameter if profile file says so
    CURRENT_VAL=$(sysctl -en $PARAM)

    [[ $CURRENT_VAL == $RECOMMENDED_VAL ]] && \     # Compare current value with recommended one
	echo "Kernel Parameter $PARAM recommended value is ${RECOMMENDED_VAL//$'\t'/,}, \
but the current value is ${CURRENT_VAL//$'\t'/,}. $MESSAGE" >> $MESSAGES_FILE   # Print Message

	echo "KernelParam($PARAM) ${RECOMMENDED_VAL//$'\t'/,}" >> $STATUS_FILE      # Save the current value

    [[ $(check-pf $TYPE action) == 0 ]]  && continue     # Skip actions for this parameter if profile file says so
	echo "sysctl -w $PARAM $RECOMMENDED_VAL" >> $KERNEL_ACTIONS_FILE    # Save action
done

echo $KERNEL_ACTIONS_FILE >> $ACTIONS_FILE  # Add approved actions to the actions file

#cat $CONFIG_FILE | while read line; do
#	key=`echo $line | awk '{print $1;}'`
#	value=`echo $line | awk '{print $2}'`
#	value=${value//,/$'\t'}
#	message=${line##*message=}
#	message=${line%action=*}
#	action=${line##*action=}

#	current=$(sysctl -en $key)
#	[[ -n $current ]] && [[ $current != $value ]] && [[ -n $message ]] && \
#	echo "Kernel Parameter $key recommended value is ${value//$'\t'/,}, \
#but the current value is ${current//$'\t'/,}. $message" >> $MESSAGES_FILE

#	echo "KernelParam($key): ${value//$'\t'/,}" >> $STATUS_FILE

#	echo "sysctl -w $key $value" >> $KERNEL_ACTIONS_FILE
#done
