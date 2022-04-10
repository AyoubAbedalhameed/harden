#!/usr/bin/bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Stop overwriting files
set -c

RUNTIME_DATE=$(date +%F_%H:%M:%S)   # Runtime date and time

# First argument should specify which mode we are running in
OPERATE_MODE=$1
shift
# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
    case $1 in
        -md|--main-directory)
            MAIN_DIR="$2"
            shift 2 # shift the arguments 2 times (we used two arguments)
            ;;
        -md=*|--main-directory=*)
            MAIN_DIR="${2#*=}"
            shift # shift the arguments once (we used a single argument)
            ;;
        -pf|--profile-file)
            PROFILE_FILE="$2"
            shift 2 
            ;;
        -pf=*|--profile-file=*)
            PROFILE_FILE="${2#*=}"
            shift
            ;;
        -mf|--messages-file)
            ;;
        -af|--actions-file)
            ;;
        -d|--date)
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

MAIN_DIR="/usr/share/harden"    # Default Main Directory
CONFIG_DIR="/etc/harden"    # Default Configuration Directory
CONFIG_FILE="$CONFIG_DIR/harden.conf"   # Default Configuration File
DEFAULT_PROFILE_FILE="$CONFIG_DIR/default.profile"  # Default Profile File
PROFILE_FILE="$CONFIG_DIR/admin-choice.profile" # Default User Choice Profile File

SCRIPTS_DIR="$MAIN_DIR/scripts" # Default Scripts Directory

STATUS_DIR="$MAIN_DIR/status"   # Default Status Directory
# Check if Directory exists, and if not then create it
[[ ! -d $STATUS_DIR ]] && mkdir $STATUS_DIR
STATUS_FILE="$STATUS_DIR/$RUNTIME_DATE.status"

MESSAGES_DIR="$MAIN_DIR/messages"   # Default Messages Directory
# Check if Directory exists, and if not then create it
[[ ! -d $MESSAGES_DIR ]] && mkdir $MESSAGES_DIR
MESSAGES_FILE="$MESSAGES_DIR/$RUNTIME_DATE.message"

ACTIONS_DIR="$MAIN_DIR/actions" # Default Actions Directory
# Check if Directory exists, and if not then create it
[[ ! -d $ACTIONS_DIR ]] && mkdir $ACTIONS_DIR
ACTIONS_FILE="$ACTIONS_DIR/$RUNTIME_DATE.sh"

# Redirect stdout and stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# (status, messages, actions) files the content of it will also be recorded in the 
# log file.
# Uncomment this line if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
#
#   LOG_FILE="/var/log/harden/$(date +%F_%H:%M:%S).log"
#   echo > $LOG_FILE
#	exec 1>>$LOG_FILE 2>&1

echo "Harden service is starting up ..."

harden-run()   {
    local CURRENT_PROFILE_FILE=$1

    # Create Log, status, messages and actions file for the current run.
    touch $STATUS_FILE $MESSAGES_FILE $ACTIONS_FILE

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
    case $OPERATE_MODE in
        setup)      RETURN_VALUE=$(harden-run $DEFAULT_PROFILE_FILE)
        ;;
        scan)       RETURN_VALUE=$(harden-run $PROFILE_FILE)
        ;;
        take-actions)        RETURN_VALUE=$(take-action)
        ;;
        list-messages)   RETURN_VALUE=$(show-messages $OPTION1)
        ;;
        list-actions)    RETURN_VALUE=$(show-actions $OPTION1)
        ;;
        *)
            echo "Please specify one of the available modes (setup - scan - act - messages - actions)"
        ;;
    esac

	return $RETURN_VALUE
}

check-and-run
exit $?
