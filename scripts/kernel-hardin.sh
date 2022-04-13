#!/usr/bin/bash
# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

CONFIG_FILE="/usr/share/harden/config/kernel-parametrs.conf"
KERNEL_ACTIONS_FILE="/usr/share/config/$(date +%F_%H:%M:%S)_kernel-actions.sh"

# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
    case $1 in
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

cat $CONFIG_FILE | while read line; do
	key=`echo $line | awk '{print $1;}'`
	value=`echo $line | awk '{print $2}'`
	value=${value//,/$'\t'}
	message=${line##*message=}
	message=${line%action=*}
	action=${line##*action=}

	current=$(sysctl -en $key)
	[[ -n $current ]] && [[ $current != $value ]] && [[ -n $message ]] && \
	echo "Kernel Parameter $key recommended value is ${value//$'\t'/,}, \
but the current value is ${current//$'\t'/,}. $message" >> $MESSAGES_FILE

	echo "KernelParam($key): ${value//$'\t'/,}" >> $STATUS_FILE

	echo "sysctl -w $key $value" >> $KERNEL_ACTIONS_FILE
done

echo $KERNEL_ACTIONS_FILE >> $ACTIONS_FILE
