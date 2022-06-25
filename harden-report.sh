#!/usr/bin/env bash

# Script to make a HTML report from the messages of the last scan

#MAIN_DIR='/usr/share/harden'
#PROFILE_FILE='/etc/harden/profile-file.json'
#MESSAGES_FILE="$MAIN_DIR/messages/harden-last-messages"

#REPORT_FILE="$MAIN_DIR/reports/last-report.html"
#mkdir -p $MAIN_DIR/reports

[[ $__RAN_BY_HARDEN_MAIN != 1 ]] && {
	echo >&2 "$0 should be called only by harden-main"
	exit 1
}

[[ $__DEBUG_X == 1 ]] && set -x

# Print startup message with run time settings
echo >&2 "\
Kernel Hardening is starting up as pid=$$ at $(date '+%F %T %s.%^4N')...
CONFIG_FILE = $CONFIG_FILE
PROFILE_FILE = $PROFILE_FILE
MESSAGES_FILE = $MESSAGES_FILE
ACTIONS_FILE = $ACTIONS_FILE
LOG_FILE=$LOG_FILE"

exec 6>&1 1>>"$REPORT_FILE"
#exec 3> >(while read -r line; do echo >&1 "<li>${line#*-}</li>"; done)

TYPES=$(jq '.[].name' "$PROFILE_FILE")

echo > "$REPORT_FILE"
echo '<html>'
echo '<head>Hardening Scan Report</head>'
echo '<title>Hardening Scan Report</title>'
echo '<body>'

for TYPE in $TYPES; do
    echo "<h3>${TYPE^^}</h3>"
    echo '<ul>'
    grep -iE "^$TYPE -\[*" "$MESSAGES_FILE" >& >(while read -r line; do echo >&1 "<li>${line#*-}</li>"; done;)
    echo '</ul>'

    SUBS=$(jq ".[] | select(.name==$TYPE) | .$TYPE | keys" config/profile-file.json | grep -vE '(action|check|question|\[|\])')
    SUBS=${SUBS//\"/}
    SUBS=${SUBS//,/}

    [[ -n $SUBS ]] && for SUB in $SUBS; do
            echo "<h4>${SUB^^}</h4>"
            echo '<ul>'
            grep -iE "^$TYPE $SUB -\[*" "$MESSAGES_FILE" >& >(while read -r line; do echo >&1 "<li>${line#*-}</li>"; done;)
            echo '</ul>'
        done
done

echo '</body>'
echo '</html>' 
