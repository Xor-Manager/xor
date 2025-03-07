#!/usr/bin/bash
set -e

LIBDIR="/usr/lib/xor"

source "$LIBDIR/lib/config.sh"
source "$LIBDIR/lib/messages.sh"
source "$LIBDIR/lib/check_command"

source "$LIBDIR/db/repositories"

#First (main)
check_already_installed() {

	if [ -f "$CONFIG_DIR/xor.conf" ]; then
		. "$CONFIG_DIR/xor.conf"
	else
		echo "Configuration file not found: $CONFIG_DIR/xor.conf"
		interrupt
	fi

	PKG_NAME=$1
	PKG_VER=""

	if [ -d "$MANAGER_DB/installed/$PKG_NAME" ]; then
		msg "Package $PKG_NAME is already installed."
		return 0
	fi

	#INFO: Check if lib is installed without the xor package manager

	if ldconfig -p | grep -q "$PKG_NAME"; then
		msg "Lib $PKG_NAME is already installed."
		return 0
	fi

	if [[ -f "/usr/lib/$PKG_NAME" || -f "/usr/local/lib/$PKG_NAME" ]]; then
		msg "Lib $PKG_NAME is already installed."
		return 0
	fi

	#INFO: Check if bin is installed without the xor package manager
	if command -v "$PKG_NAME" &>/dev/null; then
		msg "Bin $PKG_NAME is already installed."
		return 0
	fi

	#INFO: Check if header is installed without the xor package manager
	if [[ -f "/usr/include/$PKG_NAME" || -f "/usr/local/include/$PKG_NAME" ]]; then
		msg "Header $PKG_NAME is already installed."
		return 0
	fi

	check_repositories
}


check_repositories() {
	result=$(search_repositories "$PKG_NAME" | head -n 1)

	if [ -n "$result" ]; then
		echo "Package found: $result"
		echo ""
		check_dependencies

	else
		msgerr "Package not found: $PKG_NAME"
		interrupt
	fi
}

ask_to_install_dependency() {
	local dep=$1
	msgwarn "Dependency $dep not found. Want to install ? (Y/n)"

	read -r answer
	answer=${answer:-"y"}

	if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
		msg "Installing dependency: $dep"
		bash $(dirname "$0")../bin/xor install "$dep" || { msgerr "Failed to install dependency $dep"; return 1; }
	else
		msgerr "Dependency $dep not installed. The package can not work correctly."
		return 1
	fi
}


check_dependencies() {
	repo_name="$(find_pkg_repository "$PKG_NAME")"

	source "$MANAGER_REPOSITORY/$repo_name/$PKG_NAME/XORBUILD"

	if [ -z "$dependencies" ]; then

		msg3 "No dependencies for $PKG_NAME. Want to install ? (Y/n)"

		read -r answer
		answer=${answer:-"y"}
		if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
			create_temp_folder
			return 0
		else
			interrupt
		fi

	fi

	msg2 "The package $PKG_NAME requires the following dependencies:"
	if [ -z "$dependencies" ]; then
		msg "No dependencies required for $PKG_NAME."
	else
		echo "$dependencies" | tr ' ' '\n' | sed '/^$/d' | sed 's/^/   - /' | column -c 80
	fi
	echo ""


	missing_deps=()
	for dep in ${dependencies[@]}; do
		if [ ! -d "$MANAGER_INSTALLED/$dep" ]; then
			missing_deps+=("$dep")
		fi
	done

	if [ ${#missing_deps[@]} -gt 0 ]; then
		msg3 "The following dependencies are missing and will be installed:"
		printf "   - %s\n" "${missing_deps[@]}" | column -c 80


		echo ""
		msg "Process with installation ? (Y/n)"

		read -r answer
		answer=${answer:-"y"}
		if [[ "$answer" == "n" || "$answer" == "N" ]]; then
			msgwarn "Dependencies were not installed. Installation aborted."
			interrupt
		fi

		for dep in "${missing_deps[@]}"; do
			bash $(dirname "$0")/../bin/xor install "$dep" || return 1
		done
	fi

	create_temp_folder
}

create_temp_folder() {
	trap finalize EXIT INT TERM ERR

	if [ ! -d /var/tmp/$PKG_NAME ]; then
		msg "Creating Overlay and Source folder!"
		mkdir -p /var/tmp/$PKG_NAME/{sources,overlay/{upper,work,merged}}
		TMP_SOURCE_FOLDER=/var/tmp/$PKG_NAME/sources
		TMP_OVERLAY_FOLDER=/var/tmp/$PKG_NAME/overlay
	fi

	mount_overlay
}

mount_overlay() {
	if mountpoint -q $TMP_OVERLAY_FOLDER/merged; then
		msgerr "Overlay already mounted!"
		return
	fi

	sudo mount -t overlay overlay \
		-o lowerdir=/,upperdir=$TMP_OVERLAY_FOLDER/upper,workdir=$TMP_OVERLAY_FOLDER/work \
		$TMP_OVERLAY_FOLDER/merged

	if ! mountpoint -q $TMP_OVERLAY_FOLDER/merged; then
		msgerr "Overlay mount failed!"
		interrupt
	fi

	msg "Overlay mounted successfully!"
	download
}

download() {
	msg "Sourcing repository $PKG_NAME at $TMP_SOURCE_FOLDER"

	FILE_EXT=$(basename "$url" | sed 's/.*\(\.tar\..*\)/\1/')
	FILE_NAME="$PKG_NAME-$ver"

	if [ ! -f "$TMP_SOURCE_FOLDER/$FILE_NAME$FILE_EXT" ]; then
		msg2 "Downloading $FILE_NAME"

		if ! wget --waitretry=3 -O "$TMP_SOURCE_FOLDER/$FILE_NAME$FILE_EXT" "$url"; then
			msgerr "Error downloading the package $PKG_NAME from $url."
			interrupt
		fi

	else
		msg "Package $PKG_NAME already downloaded."
	fi

	unpack
}

unpack() {

	if [ ! -f "$TMP_SOURCE_FOLDER/$FILE_NAME$FILE_EXT" ]; then
		msgerr "Package archive not found: $FILE_NAME$FILE_EXT"
		interrupt
	fi

	msg2 "Unpacking $FILE_NAME"
	if ! tar -xf "$TMP_SOURCE_FOLDER/$FILE_NAME$FILE_EXT" -C "$TMP_SOURCE_FOLDER/"; then
		msgerr "Error unpacking $FILE_NAME"
		interrupt
	fi

	#FILE_NAME=$(ls $TMP_SOURCE_FOLDER -td */ | head -n 1 | tr -d '/')
	FILE_NAME=$(find "$TMP_SOURCE_FOLDER" -mindepth 1 -maxdepth 1 -type d | head -n 1 | xargs basename)

	if [ -z "$TMP_SOURCE_FOLDER/$FILE_NAME" ]; then
		msgerr "Unpacking failed: No directory found"
		interrupt
	fi

	msg "Creating build folder"
	if [ -d "$TMP_SOURCE_FOLDER/$FILE_NAME/build" ]; then
		mkdir -p "$TMP_SOURCE_FOLDER/$FILE_NAME/build"
	fi

	full_install
}


full_install() {

	pushd "$TMP_SOURCE_FOLDER/$FILE_NAME"
		if check_function prepare; then
			prepare
		fi

		if check_function configure; then
			configure
			if ! configure; then
				msgerr "Configure step failed."
				return 1
			fi
		fi
	popd

	#INFO: AFTER THIS WE ARE CHROOTED

	if mountpoint -q "$TMP_OVERLAY_FOLDER/merged"; then

sudo chroot "$TMP_OVERLAY_FOLDER/merged" /bin/bash <<EOF

			source /opt/xor/core/config.sh

			source "$MANAGER_REPOSITORY/$repo_name/$PKG_NAME/XORBUILD"

			pushd "$TMP_SOURCE_FOLDER/$FILE_NAME"
			pwd

				# if declare -f "prepare" &>/dev/null; then
				# 	prepare
				# fi
				#
				# if declare -f "configure" &>/dev/null; then
				# 	configure
				# 	if ! configure; then
				# 		msgerr "Configure step failed."
				# 		return 1
				# 	fi
				# fi



				if declare -f "build" &>/dev/null; then
					build
				fi

				if declare -f "after" &>/dev/null; then
					after
				fi

				if declare -f "test" &>/dev/null; then
					test
				fi

			popd
EOF
	else
		msgerr "No mount point for chroot"
		return 1
	fi

	#prepare
	#configure
	#install
	#after
	#test

	#INFO: Not chrooted anymore
	# exit &&

	# log_installed
	install_log_files
}

install_log_files() {
	msg3 "Installing and logging files"
	local upper="$TMP_OVERLAY_FOLDER/upper"
	local directories=("/usr" "/etc" "/opt" "/lib" "/sbin" "/var/lib")

	installed_files=""

	for dir in "${directories[@]}"; do
		if [ -d "$upper$dir" ]; then
			msg "Copying $dir files..."
			sudo cp -ar "$upper$dir" / && {
				# installed_files+=$(find "$upper$dir" | sed "s|^\./|$dir/|")$'\n'
				installed_files+=$(find "$upper$dir" -type f | sed "s|^$upper||")$'\n'

			} || {
				msgerr "Failed to copy $dir files."
				return 1
			}
		else
			msgwarn "No $dir directory found in the overlay."
		fi
	done

	adding_installed_db

}

adding_installed_db() {
	local folder="$MANAGER_INSTALLED/$PKG_NAME"
	mkdir -p "$folder"
	echo "$ver" > "$folder/version"
	echo "$url" > "$folder/url"

	if [ -n "$dependencies" ]; then
		echo "$dependencies" > "$folder/dependencies"
	else
		touch "$folder/dependencies"
	fi

	echo "$installed_files" > "$folder/paths"
}

finalize() {

	msg "Checking chroot"
	if is_chroot; then
		exit
	fi
	msg "Exiting chroot"

	#TODO: Create all the messages here
	msg "Unmounting overlay"
	if mountpoint -q $TMP_OVERLAY_FOLDER/merged; then
		sudo umount $TMP_OVERLAY_FOLDER/merged
	fi
	msg "Overlay Unmounted"

	msg "Cleaning up temporary files"
	if [ -d /var/tmp/$PKG_NAME ]; then
		rm -rf /var/tmp/$PKG_NAME
	fi

	if [ -d $TMP_SOURCE_FOLDER ]; then
		rm -rf $TMP_SOURCE_FOLDER
	fi
	msg "Cleanup completed."

	#interrupt
}
