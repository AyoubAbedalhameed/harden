#!/usr/bin/bash
# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

CONFIG_FILE="/usr/share/harden/config/kernel-parametrs.conf"
STATUS_FILE=$1
MESSAGES_FILE=$2
ACTIONS_FILE=$3
KERNEL_ACTIONS_FILE="/usr/share/config/$(date +%F_%H:%M:%S)_kernel-actions.sh"

cat $CONFIG_FILE | while read line; do
	key=`echo $line | awk '{print $1;}'`
	value=`echo $line | awk '{print $2}'`
	value=${value//,/$'\t'}
	message=${line##*message=}
	action=${line##*action=}

	current=$(sysctl -en $key)
	[[ -n $current ]] && [[ $current != $value ]] && [[ -n $message ]] && \
	echo "Kernel Parameter $key recommended value is ${value//$'\t'/,}, \
but the current value is ${current//$'\t'/,}. $message" >> $MESSAGES_FILE

	echo "KernelParam($key): ${value//$'\t'/,}" >> $STATUS_FILE

	echo "sysctl -w $key $value" >> $KERNEL_ACTIONS_FILE
done

echo $KERNEL_ACTIONS_FILE >> $ACTIONS_FILE
