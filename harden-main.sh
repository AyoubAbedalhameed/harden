#!/usr/bin/bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

OPERATE_MODE=$1

MAIN_DIR="/usr/share/harden"
SCRIPTS_DIR="$MAIN_DIR/scripts/"
MESSAGES_DIR="$MAIN_DIR/messages/"
ACTIONS_DIR="$MAIN_DIR/actions"
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
# exec 1>>$LOG_FILE 2>>$LOG_FILE

echo "Harden service is starting up ..."

harden-run()   {
    local CURRENT_PROFILE_FILE=$1

    # Create Log and status file forthe current run.
    #echo > $LOG_FILE
    echo > $STATUS_FILE

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
        script=$(echo $line | awk '{print $3;}')
        bash $script $STATUS_FILE $MESSAGES_FILE $ACTIONS_FILE
    done

    echo "Harden service has finished"
}

take-action()   {
    echo "Taking Actions from file " $()
    bash /usr/share/harden/last-actions
}

show-messages() {
    local MESSAGES_DATE=$1
    [[ $(ls "$MESSAGES_DIR/$MESSAGES_DATE*" | wc -w) == 0 ]] && echo "No messages found for this date"

    for i in "$MESSAGES_DIR/$MESSAGES_DATE*"
    do
        cat $i
    done
}

show-actions()  {
    local ACTIONS_DATE=$1
    [[ $(ls "$ACTIONS_DIR/$ACTIONS_DATE*" | wc -w) == 0 ]] && echo "No actions found for this date"

    for i in "$ACTIONS_DIR/$ACTIONS_DATE*"
    do
        cat $i
    done
}

# Check what mode we are running in
[[ $OPERATE_MODE == "setup" ]] && harden-run $DEFAULT_PROFILE_FILE
[[ $OPERATE_MODE == "scan" ]] && harden-run $PROFILE_FILE
[[ $OPERATE_MODE == "act" ]] && take-action
[[ $OPERATE_MODE == "messages" ]] && show-messages $2
[[ $OPERATE_MODE == "actions" ]] && show-actions $2
