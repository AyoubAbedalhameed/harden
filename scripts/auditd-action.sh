#!/usr/bin/bash

UNMATCHED_RULES_FILE="/usr/share/harden/resources/harden-custom-audit.rules"
HARDEN_CUSTOM_RULES_FILE="/etc/audit/rules.d/harden-custom-audit.rules"

[[ ! -f $UNMATCHED_RULES_FILE ]] && echo "unmatched_rules file does not exist, Skipping action." && exit 1


while read RULE ; do 
    grep -e "$RULE" $HARDEN_CUSTOM_RULES_FILE >> /dev/null ||  echo "$RULE" >> $HARDEN_CUSTOM_RULES_FILE ; done <"$UNMATCHED_RULES_FILE"


augenrules --load > /dev/null
