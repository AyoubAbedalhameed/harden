#!/usr/bin/env bash

# Script to make a HTML report from the messages of the last scan

[[ $__DEBUG_X == 1 ]] && set -x

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
    RUNTIME_DATE=$(date '+%s_%F')
    DATE=$(date)

    MAIN_DIR='/usr/share/harden'
    PROFILE_FILE='/etc/harden/profile-file.json'
    [[ ! -h $MAIN_DIR/messages/harden-last-messages ]] && { echo "No messages found"; exit; }
    MESSAGES_FILE=$(readlink $MAIN_DIR/messages/harden-last-messages)
    [[ ! -f $MESSAGES_FILE ]] && { echo "No messages found"; exit; }

    REPORT_FILE="$MAIN_DIR/reports/harden-report_$RUNTIME_DATE.html"
    mkdir -p $MAIN_DIR/reports

    RUNTIME_DATE_FROM=$(readlink "$MESSAGES_FILE")
    RUNTIME_DATE_FROM=${RUNTIME_DATE_FROM#*_}
    RUNTIME_DATE_FROM=${RUNTIME_DATE_FROM%_*}
    RUNTIME_DATE_FROM=$(date -d @$RUNTIME_DATE_FROM)
}

DATE=${DATE:=DATE}
RUNTIME_DATE_FROM=${RUNTIME_DATE_FROM:=$DATE}

[[ ! -h $MAIN_DIR/messages/harden-last-messages ]] && { echo "No messages found"; exit; }
[[ ! -f $MESSAGES_FILE ]] && { echo "No messages found"; exit; }

# Print startup message with run time settings
echo >&2 "\
Reporting script is starting up as pid=$$ at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"


echo > "$REPORT_FILE"
exec 6>&1 1>>"$REPORT_FILE"
#exec 3> >(while read -r line; do echo >&1 "<li>${line#*-}</li>"; done)

TYPES=$(jq '.[].name' "$PROFILE_FILE")
TYPES=${TYPES//\"/}

echo '<html>'
echo "<h1>Hardening Scan Report</h1>"
echo "<h3>Created at: ($DATE) From a scan at: ($RUNTIME_DATE_FROM)</h3>"
echo "<h3>Info obtained from the messages file $MESSAGES_FILE</h3>"
echo '<title>Hardening Scan Report</title>'
echo '<body>'

for TYPE in $TYPES; do
    echo "<h3>${TYPE^^} Module</h3>"
    echo '<ul>'
    grep -iE "^$TYPE -\[*" "$MESSAGES_FILE" >& >(while read -r line; do echo "<li>${line#*-}</li>"; done;)
    sleep 0.1

    SUBS=$(jq ".[] | select(.name==\"$TYPE\") | .$TYPE | keys" config/profile-file.json | grep -vE '(action|check|question|\[|\])')
    SUBS=${SUBS//\"/}
    SUBS=${SUBS//,/}
#    echo $TYPE:$'\t'$SUBS

    [[ -n $SUBS ]] && for SUB in $SUBS; do
        echo "<h4>${SUB^^} Sub-Module</h4>"
        echo '<ul>'
        grep -iE "^$TYPE $SUB -\[*" "$MESSAGES_FILE" >& >(while read -r line; do echo "<li>${line#*-}</li>"; done;)
        sleep 0.1
        echo '</ul>'
    done

    echo '</ul>' #>> $REPORT_FILE
done

echo '</body>'
echo '</html>'

echo >&6 "Report created succefully and saved by at file $REPORT_FILE"