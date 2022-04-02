#!/usr/bin/bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

OPERATE_MODE=$1
OPTION1=$2

MAIN_DIR="/usr/share/harden"
SCRIPTS_DIR="$MAIN_DIR/scripts"

STATUS_DIR="$MAIN_DIR/status"
[[ -e $STATUS_DIR ]] && mkdir $STATUS_DIR

MESSAGES_DIR="$MAIN_DIR/messages"
[[ -e $MESSAGES_DIR ]] && mkdir $MESSAGES_DIR

ACTIONS_DIR="$MAIN_DIR/actions"
[[ -e $ACTIONS_DIR ]] && mkdir $ACTIONS_DIR

CONFIG_FILE="/etc/harden/harden.conf"
DEFAULT_PROFILE_FILE="/etc/harden/default.profile"
PROFILE_FILE="/etc/harden/admin-choice.profile"
#LOG_FILE="/var/log/harden/$(date +%F_%H:%M:%S).log"
STATUS_FILE="$STATUS_DIR/$(date +%F_%H:%M:%S).status"
MESSAGES_FILE="$MESSAGES_DIR/$(date +%F_%H:%M:%S).message"
ACTIONS_FILE="$ACTIONS_DIR/$(date +%F_%H:%M:%S).sh"

# Redirect stdout and stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# status file the content of it will also be recorded in the 
# log file.
# Uncomment this line if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
#   echo > $LOG_FILE
#	exec 1>>$LOG_FILE 2>&1

echo "Harden service is starting up ..."

harden-run()   {
    local CURRENT_PROFILE_FILE=$1

    # Create Log, status, messages and actions file forthe current run.
    echo > $STATUS_FILE > $MESSAGES_FILE > $ACTIONS_FILE

    # Run tail command in follow mode in the background, so we can
    # get the data from the status file in stdout automatically.
    tail -f $STATUS_FILE &

    # Set a trap condition for the tail command, so it will end,
    # when the process (script) exits.
    trap "pkill -P $$" EXIT

    tail -f $MESSAGES_FILE &
    trap "pkill -P $$" EXIT

    tail -f $ACTIONS_FILE &
    trap "pkill -P $$" EXIT

    # Create/relink a symlink to the last status file
    [[ -e /usr/share/harden/last-status ]] && rm /usr/share/harden/last-status
    ln -s $STATUS_FILE /usr/share/harden/last-status
    [[ -e /usr/share/harden/last-messages ]] && rm /usr/share/harden/last-messages
    ln -s $MESSAGES_FILE /usr/share/harden/last-messages
    [[ -e /usr/share/harden/last-actions ]] && rm /usr/share/harden/last-actions
    ln -s $ACTIONS_FILE /usr/share/harden/last-actions

    echo "$(date)" >> $MESSAGES_FILE
    echo "# Created at $(date)" >> $ACTIONS_FILE

    cat $CURRENT_PROFILE_FILE | while read line; do
        rule=$(echo $line | awk '{print $1;}')
        script=$(echo $line | awk '{print $2;}')
        bash $script $STATUS_FILE $MESSAGES_FILE $ACTIONS_FILE
    done

    echo "Harden service has finished"

    return 0
}

take-action()   {
    echo "Taking Actions from file $MAIN_DIR/last-actions"
    bash "$MAIN_DIR/last-actions"
    return $?
}

show-messages() {
    local MESSAGES_DATE=$1
    [[ $(ls "$MESSAGES_DIR/$MESSAGES_DATE*" | wc -w) == 0 ]] && echo "No messages found for this date ($MESSAGES_DATE)" && return 1

    for i in "$MESSAGES_DIR/$MESSAGES_DATE*"
    do
        cat $i
    done

    return 0
}

show-actions()  {
    local ACTIONS_DATE=$1
    [[ $(ls "$ACTIONS_DIR/$ACTIONS_DATE*" | wc -w) == 0 ]] && echo "No actions found for this date ($ACTIONS_DATE)" && return 1

    for i in "$ACTIONS_DIR/$ACTIONS_DATE*"
    do
        cat $i
    done

    return 0
}

check-and-run()	{
	local RETURN_VALUE=""
	# Check what mode we are running in
	[[ $OPERATE_MODE == "setup" ]] && RETURN_VALUE=$(harden-run $DEFAULT_PROFILE_FILE)
	[[ $OPERATE_MODE == "scan" ]] && RETURN_VALUE=$(harden-run $PROFILE_FILE)
	[[ $OPERATE_MODE == "act" ]] && RETURN_VALUE=$(take-action)
	[[ $OPERATE_MODE == "messages" ]] && RETURN_VALUE=$(show-messages $OPTION1)
	[[ $OPERATE_MODE == "actions" ]] && RETURN_VALUE=$(show-actions $OPTION1)

	return $RETURN_VALUE
}

check-and-run
exit $?
