#!/usr/bin/env bash
set -e

tmp_install=/var/tmp/xor
install_folder=/opt/xor
backup=/var/tmp/backup_xor

restore_backup() {
	if [ -d "$backup" ]; then
		sudo mv "$backup" "$install_folder"
	fi
}

trap restore_backup ERR

if [ ! -d "$tmp_install" ]; then
	mkdir -p "$tmp_install"
fi

git clone https://github.com/Xor-Manager/xor "$tmp_install"

if [ -d "$install_folder" ]; then
	sudo mv "$install_folder" "$backup"
else
	sudo mkdir -p "$install_folder"
fi

sudo mv "$tmp_install"/* "$install_folder"/

rm -r $backup
rm -r $tmp_install
