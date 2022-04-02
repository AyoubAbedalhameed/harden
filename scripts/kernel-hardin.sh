#!/usr/bin/bash
# Kernel Parameters hardening through checking and warning with
# recommended solutions and tips

CONFIG_FILE="/usr/share/harden/config/kernel-parametrs.conf"
STATUS_FILE=$1
MESSAGES_FILE=$2
ACTIONS_FILE=$3

cat $CONFIG_FILE | while read line; do
	key=`echo $line | awk '{print $1;}'`
	value=`echo $line | awk '{print $2}'`
	value=${value//,/$'\t'}
	message=${line##*message=}

	current=`sysctl -en $key`
	[[ -n $current ]] && [[ $current != $value ]] && [[ -n $message ]] && \
	echo "Kernel Parameter $key recommended value is ${value//$'\t'/,}, \
but the current value is ${current//$'\t'/,}. $message" >> $MESSAGES_FILE

	echo "KernelParam($key): ${value//$'\t'/,}" >> $STATUS_FILE
done

echo "sysctl -w $key $value" >> $ACTIONS_FILE
echo "$(pwd)/filename.sh" >> $ACTIONS_FILE
