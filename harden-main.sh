#!/usr/bin/env bash
# Written By: Adnan Omar (aalkhaldi8@gmail.com)

# Prevent overwriting files, if then the script will exit
set -c

usage() {   echo "Usage: $0 -cf/--config-file [configuration file] -pf/--profile-file [profile file] \
-st/--status-file [status file] -mf/--messages-file [messages file] -af/--actions-file [actions file] \
-d/--date [date in YYYY-MM-DD format]"   }

RUNTIME_DATE=$(date +%F_%H:%M:%S)   # Runtime date and time

# First argument should specify which mode we are running in
OPERATE_MODE=$1
shift
# Loop through all command line arguments, and but them in
# the case switch statement to test them
while [[ $# -gt 0 ]]; do
    case $1 in
        -cf|--config-file)  # Use a configuration file from user choice
            CONFIG_FILE=$2
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
        -pf|--profile-file) # Use a profile file from user choice
            PROFILE_FILE="$2"
            shift 2 
            ;;
        -d|--date)  # This option is used in (list-messages, list-actions) operate modes
            DATE_TO_LIST=$2
            shift 2
            ;;
        -*|--*)
            echo "Unknown option $1"
            usage
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

CONFIG_DIR="/etc/harden"    # Default Configuration Directory
DEFAULT_PROFILE_FILE="$CONFIG_DIR/default.profile"  # Default Profile File

MAIN_DIR="/usr/share/harden"    # Default Main Directory
SCRIPTS_DIR="$MAIN_DIR/scripts" # Default Scripts Directory

STATUS_DIR="$MAIN_DIR/status"   # Default Status Directory
[[ ! -d $STATUS_DIR ]] && mkdir $STATUS_DIR # Check if Directory exists, and if not then create it
MESSAGES_DIR="$MAIN_DIR/messages"   # Default Messages Directory
[[ ! -d $MESSAGES_DIR ]] && mkdir $MESSAGES_DIR # Check if Directory exists, and if not then create it
ACTIONS_DIR="$MAIN_DIR/actions" # Default Actions Directory
[[ ! -d $ACTIONS_DIR ]] && mkdir $ACTIONS_DIR   # Check if Directory exists, and if not then create it

CONFIG_FILE=${CONFIG_FILE:="$CONFIG_DIR/harden.conf"}   # Use Default Configuration File,
                            # if not set by a positional parameter (command line argument)
PROFILE_FILE=${PROFILE_FILE:="$CONFIG_DIR/admin-choice.profile"}    # Default User Choice Profile File
STATUS_FILE=${STATUS_FILE:="$STATUS_DIR/$RUNTIME_DATE.status"}  # Currently used status file
MESSAGES_FILE=${MESSAGES_FILE:="$MESSAGES_DIR/$RUNTIME_DATE.message"}   # Currently used messages file
ACTIONS_FILE=${ACTIONS_FILE:="$ACTIONS_DIR/$RUNTIME_DATE.sh"}   # Currently used Actions file

# Redirect stdout and stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# (status, messages, actions) files the content of it will also be recorded in the 
# log file.
# Uncomment these lines if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
#
#   LOG_FILE="/var/log/harden/$(date +%F_%H:%M:%S).log"
#   echo > $LOG_FILE
#   exec 1>>$LOG_FILE 2>&1

# Print startup message with run time settings
echo "\
Harden service is starting up ...
CONFIG_FILE = $CONFIG_FILE
MAIN_DIR = $MAIN_DIR
PROFILE_FILE = $PROFILE_FILE
STATUS_FILE = $STATUS_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE"

harden-run()   {
    local CURRENT_PROFILE_FILE=$1

    # Create Log, status, messages and actions file for the current run.
    touch $STATUS_FILE $MESSAGES_FILE $ACTIONS_FILE

    tail -f $STATUS_FILE &  # Run tail command in follow mode in the
                # background, so we can get the data from
                # the status file in stdout automatically.
    trap "pkill -P $$" EXIT # Set a trap condition for the tail command,
                # so it will end, when the process (script) exits.
    tail -f $MESSAGES_FILE &
    trap "pkill -P $$" EXIT
    tail -f $ACTIONS_FILE &
    trap "pkill -P $$" EXIT

    # Create/relink a symlink to the last status file
    [[ -e "$MAIN_DIR/last-status" ]] && rm "$MAIN_DIR/last-status"
    [[ -e "$MAIN_DIR/last-messages" ]] && rm "$MAIN_DIR/last-messages"
    [[ -e "$MAIN_DIR/last-actions" ]] && rm "$MAIN_DIR/last-actions"
    ln -s $STATUS_FILE "$MAIN_DIR/last-status"
    ln -s $MESSAGES_FILE "$MAIN_DIR/last-messages"
    ln -s $ACTIONS_FILE "$MAIN_DIR/last-actions"

    cat $CURRENT_PROFILE_FILE | while read line; do
        rule=$(echo $line | awk '{print $1;}')
        script=$(echo $line | awk '{print $2;}')
        if [[ ${script%/*} -eq $SCRIPTS_DIR ]] then
            bash $script -sf $STATUS_FILE -mf $MESSAGES_FILE -af $ACTIONS_FILE -md $MAIN_DIR
        else
            echo "Script $script does not exist not in the $SCRIPTS_DIR."
        fi
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
    if [[ $(ls "$MESSAGES_DIR/$DATE_TO_LIST*" | wc -w) == 0 ]] then
        echo "No messages found for this date ($DATE_TO_LIST)"
        return 1
    else
        for i in "$MESSAGES_DIR/$DATE_TO_LIST*"
        do
            cat $i
        done
        return 0
    fi
}

show-actions()  {
    if [[ $(ls "$ACTIONS_DIR/$DATE_TO_LIST*" | wc -w) == 0 ]] then
        echo "No actions found for this date ($DATE_TO_LIST)"
        return 1
    else
        for i in "$ACTIONS_DIR/$DATE_TO_LIST*"
        do
            cat $i
        done
        return 0
    fi
}

check-and-run() {
    local RETURN_VALUE=""
    # Check what mode we are running in
    case $OPERATE_MODE in
        setup)  RETURN_VALUE=$(harden-run $DEFAULT_PROFILE_FILE)
        ;;
        scan)   RETURN_VALUE=$(harden-run $PROFILE_FILE)
        ;;
        take-actions)   RETURN_VALUE=$(take-action)
        ;;
        list-messages)  RETURN_VALUE=$(show-messages)
        ;;
        list-actions)   RETURN_VALUE=$(show-actions)
        ;;
        *)  echo "Please specify one of the available modes (setup - scan - act - messages - actions)"
        ;;
    esac
    return $RETURN_VALUE
}

check-and-run
exit $?


