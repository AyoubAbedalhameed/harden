#!/usr/bin/env bash

MAIN_DIR='/usr/share/harden'

if [[ $(pwd) != $MAIN_DIR ]]; then
	if [[ ! -d $MAIN_DIR ]]; then
		mkdir $MAIN_DIR
		cp -r ./* $MAIN_DIR/
	fi
	cd $MAIN_DIR
fi

mkdir -p /etc/harden
ln -s $MAIN_DIR/config/profle-file.json /etc/harden/profile-file.json

ln -s $MAIN_DIR/systemd-units/harden.service /usr/lib/systemd/system/harden.service
ln -s $MAIN_DIR/systemd-units/harden.timer /usr/lib/systemd/system/harden.timer
ln -s $MAIN_DIR/systemd-units/harden-cleanup.service /usr/lib/systemd/system/harden-cleanup.service
ln -s $MAIN_DIR/systemd-units/harden-cleanup.timer /usr/lib/systemd/system/harden-cleanup.timer

ln -s $MAIN_DIR/harden-run.sh /usr/bin/harden-run

systemctl start harden.timer
systemctl enable harden.timer

systemctl start harden-cleanup.timer
systemctl enable harden-cleanup.timer
