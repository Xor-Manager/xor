#!/usr/bin/env bash
set -e

source ./config.sh
source ./messages.sh

PKG_NAME=$1

remove_package() {

	PKG_NAME=$1

	if [ ! -f "$MANAGER_DB/installed/$PKG_NAME" ]; then
		msgerr "Package $PKG_NAME not found in the installed database."
		interrupt
	fi

	msg "Removing package: $PKG_NAME"
	installed_files=$(cat "$MANAGER_DB/paths/$PKG_NAME")

	for file in $installed_files; do
		if [ -f "$file" ]; then
			sudo rm -f "$file"
			msg3 "Removed file: $file"
		elif [ -d "$file" ]; then
			sudo rm -rf "$file"
			msg2 "Removed directory: $file"
		else
			msgwarn "File or directory $file not found, skipping."
		fi
	done

	sudo rm -f "$MANAGER_DB/paths/$PKG_NAME"
	msg2 "Package $PKG_NAME has been removed from the paths database."

	sudo rm -f "$MANAGER_DB/installed/$PKG_NAME"
	msg2 "Package $PKG_NAME has been removed from the installed database."
}
