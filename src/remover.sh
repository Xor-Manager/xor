#!/usr/bin/env bash
set -e

LIBDIR="/usr/lib/xor"

source "$LIBDIR/lib/config.sh"
source "$LIBDIR/lib/messages.sh"

PKG_NAME=$1

remove_package() {

	PKG_NAME=$1

	# if [ 

	local installed_files="$MANAGER_INSTALLED/$PKG_NAME/paths"

	if [ ! -f "$installed_files" ]; then
		msgerr "Package $PKG_NAME not found in the installed database."
		interrupt
	fi

	msg "Removing package: $PKG_NAME"

	for file in $(cat $installed_files); do
		if [ -f "$file" ]; then
			rm -f "$file"
			msg3 "Removed file: $file"
		elif [ -d "$file" ]; then
			rm -rf "$file"
			msg2 "Removed directory: $file"
		else
			msgwarn "File or directory $file not found, skipping."
		fi
	done

	rm -rf "$MANAGER_INSTALLED/$PKG_NAME"
	msg2 "Package $PKG_NAME has been removed."
}
