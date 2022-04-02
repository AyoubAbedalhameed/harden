#!/usr/bin/bash
# Written By: Adnan Omar (@gmail.com)

CONFIG_FILE="/etc/harden/harden.conf"
DEFAULT_PROFILE_FILE="/etc/harden/default.profile"
PROFILE_FILE="/etc/harden/admin-choice.profile"
SCRIPTS_DIR="/usr/share/harden/scripts/"
LOG_FILE="/var/log/harden/$(date +%F_%H:%M:%S).log"
STATUS_FILE="/usr/share/harden/status/$(date +%F_%H:%M:%S).status"
MESSAGES_FILE="/usr/share/harden/messages/$(date +%F_%H:%M:%S).message"
ACTIONS_FILE="/usr/share/harden/actions/$(date +%F_%H:%M:%S).sh"

# Create Log and status file forthe current run.
echo > $LOG_FILE > $STATUS_FILE

# Run tail command in follow mode in the background, so we can
# get the data from the status file in stdout automatically.
tail -f $STATUS_FILE &

# Set a trap condition for the tail command, so it will end,
# when the process (script) exits.
trap "pkill -P $$" EXIT

# Redirect stdout and stderr to the log file, so everything
# will be recorded in it. Also, due to the tail command on the
# status file the content of it will also be recorded in the 
# log file.
# Uncomment this line if you chose to use journald for logging
# (by setting the StandardOutput & StandardError variables
# in the service unit file to "journal")
# exec 1>>$LOG_FILE 2>>$LOG_FILE

# Create/relink a symlink to the last status file
ln -s /usr/share/harden/last-status $STATUS_FILE
ln -s /usr/share/harden/last-messages $MESSAGES_FILE
ln -s /usr/share/harden/last-actions $ACTIONS_FILE

echo "Harden service is starting up ..."

harden-run()   {
    local CURRENT_PROFILE_FILE=$1

    cat $CURRENT_PROFILE_FILE | while read line; do
        script=$(echo $line | awk '{print $3;}')
        bash $script $STATUS_FILE $MESSAGES_FILE $ACTIONS_FILE
    done
}

take-action()   {
    
}

message=${line##message=}
echo $message

# Check what mode we are running is (setup or normal)
[[ $1 == "setup" ]] && harden-run $DEFAULT_PROFILE_FILE
[[ $1 == "scan" ]] && harden-run $PROFILE_FILE
[[ $1 == "action" ]] && take-action