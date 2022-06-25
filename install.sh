#!/usr/bin/env bash

MAIN_DIR='/usr/share/harden'

[[ $(id -u) != 0 ]] && {
	echo >&2 "$0: Must run as a root (uid=0,gid=0)"
	_usage_function
	exit 0
}

dnf list installed jq >& /dev/null || {
	echo 'Package "jq" is a dependancy, but not installed. Installing "jq" package...'
	dnf install jq -y && {
		echo 'The installation of package "jq" did not succeeded, aborting the installation...'
		exit
	}
	echo 'Installed Package "jq" succesfully'
}

if [[ $(pwd) != "$MAIN_DIR" ]]; then
	if [[ ! -d $MAIN_DIR ]]; then
		mkdir $MAIN_DIR
		cp -r ./* $MAIN_DIR/
	fi
	cd "$MAIN_DIR" || exit
fi

mkdir -p /etc/harden
ln -fs $MAIN_DIR/config/profile-file.json /etc/harden/profile-file.json

ln -fs $MAIN_DIR/systemd-units/harden.service /usr/lib/systemd/system/harden.service
ln -fs $MAIN_DIR/systemd-units/harden.timer /usr/lib/systemd/system/harden.timer
ln -fs $MAIN_DIR/systemd-units/harden-cleanup.service /usr/lib/systemd/system/harden-cleanup.service
ln -fs $MAIN_DIR/systemd-units/harden-cleanup.timer /usr/lib/systemd/system/harden-cleanup.timer

ln -fs $MAIN_DIR/harden-run.sh /usr/bin/harden-run

systemctl daemon-reload

systemctl start harden.timer
systemctl enable harden.timer

systemctl start harden-cleanup.timer
systemctl enable harden-cleanup.timer
