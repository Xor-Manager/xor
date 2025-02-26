#!/usr/bin/bash
set -e
# set -x

source $(dirname "$0")/../core/config.sh
source $(dirname "$0")/../core/messages.sh

source $(dirname "$0")/../database/repositories
source $(dirname "$0")/../core/check_command

PKG_NAME=$1
PKG_VER=$2

#First (main)
check_already_installed() {
	PKG_NAME=$1

	if [ -d "$MANAGER_DB/installed/$PKG_NAME" ]; then
		msg "Package $PKG_NAME is already installed."
		interrupt
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
	source "$MANAGER_REPOSITORY/$PKG_NAME/XORBUILD"

	if [ -z "$PKG_DEPENDENCIES" ]; then

		msg3 "No dependencies for $PKG_NAME. Want to install ? (Y/n)"

		read -r answer
		answer=${answer:-"y"}
		if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
			download
			return 0
		else
			interrupt
		fi

	fi

	msg2 "The package $PKG_NAME requires the following dependencies:"
	if [ -z "$PKG_DEPENDENCIES" ]; then
		msg "No dependencies required for $PKG_NAME."
	else
		echo "$PKG_DEPENDENCIES" | tr ' ' '\n' | sed '/^$/d' | sed 's/^/   - /' | column -c 80
	fi
	echo ""


	if [ "$INTERACTIVE_MODE" == "true" ]; then

		for dep in $PKG_DEPENDENCIES; do
			if [ ! -d "$MANAGER_INSTALLED/$dep" ]; then
				ask_to_install_dependency "$dep"
			else
				msg "Dependency $dep already installed."
			fi
		done
	else
		missing_deps=()
		for dep in $PKG_DEPENDENCIES; do
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
				exit 1
			fi

			for dep in "${missing_deps[@]}"; do
				bash $(dirname "$0")/../bin/xor install "$dep"
			done
		fi
	fi

	download
}

download() {
	msg "Sourcing repository $PKG_NAME"

	if [ ! -d "$MANAGER_ARCHIVES/$PKG_NAME" ]; then
		mkdir -p "$MANAGER_ARCHIVES/$PKG_NAME" || { msgerr "Failed to create directory $MANAGER_ARCHIVES/$PKG_NAME"; exit 1; }
	fi


	FILE_EXT=$(basename "$PKG_URL" | sed 's/.*\(\.tar\..*\)/\1/')
	FILE_NAME="$PKG_NAME-$PKG_VER"

	if [ ! -f "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" ]; then
		msg2 "Downloading $FILE_NAME"


		#INFO: Progress bar for wget if the system has the pv command
		if check_pv; then
			if ! wget --waitretry=3 -O "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" "$PKG_URL" | pv -n > /dev/null; then
				msgerr "Error downloading the package $PKG_NAME with pv."
				exit 1
			fi
		else
			if ! wget --waitretry=3 -O "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" "$PKG_URL"; then
				msgerr "Error downloading the package $PKG_NAME."
				exit 1
			fi
		fi

	else
		msg "Package $PKG_NAME already downloaded."
	fi

	unpack
}

unpack() {
	cd "$MANAGER_ARCHIVES/$PKG_NAME"

	if [ ! -f "$FILE_NAME$FILE_EXT" ]; then
		msgerr "Package archive not found: $FILE_NAME$FILE_EXT"
		exit 1
	fi



	msg2 "Unpacking $FILE_NAME"
	tar xf "$FILE_NAME$FILE_EXT" || { msgerr "Error unpacking $FILE_NAME"; exit 1; }

	FILE_NAME=$(ls -td */ | head -n 1 | tr -d '/')

	if [ -z "$FILE_NAME" ]; then
		msgerr "Unpacking failed: No directory found"
		exit 1
	fi

	msg "Creating build folder"
	mkdir -p "$FILE_NAME/build"
	cd - > /dev/null

	call_configure
}

call_configure() {
	pushd "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME/build" > /dev/null
		echo $(pwd)
		configure
	popd

	call_build

}

call_build(){
	pushd "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME/build" > /dev/null
		build
	popd

	installing
}

install_and_log() {
	local src_dir="$1"
	local dest_dir="$2"
	local package_name="$3"

	if [ ! -d "$src_dir" ]; then
		msgerr "Source directory $src_dir does not exist!"
		return 1
	fi

	mkdir -p "$dest_dir"

	for file in "$src_dir"/*; do
		if [ -f "$file" ]; then
			dest_file="$dest_dir/$(basename "$file")"

			# echo "Installing $file to $dest_file"
			install -Dm755 "$file" "$dest_file" && echo "$dest_file" | tee -a "$TMP_PATH_FILES" > /dev/null
			msg2 "Installed: $dest_file"

		elif [ -d "$file" ]; then
			new_dest_dir="$dest_dir/$(basename "$file")"
			install_and_log "$file" "$new_dest_dir" "$package_name"
		fi
	done
}

installing() {
	TMP_PATH_FILES=$(mktemp)

	if [ -d "$PREFIX/bin" ]; then
		install_and_log "$PREFIX/bin" "/usr/bin" "$PKG_NAME"
	fi

	if [ -d "$PREFIX/lib" ]; then
		install_and_log "$PREFIX/lib" "/usr/lib" "$PKG_NAME"
	fi

	if [ -d "$PREFIX/include" ]; then
		install_and_log "$PREFIX/include" "/usr/include" "$PKG_NAME"
	fi

	if [ -d "$PREFIX/share" ]; then
		install_and_log "$PREFIX/share" "/usr/share" "$PKG_NAME"
	fi

	if [ -d "$PREFIX/release" ]; then
		install_and_log "$PREFIX/release" "/opt/niri" "$PKG_NAME"
	fi

	# remove_archives
	adding_installed_db
	trap cleanup EXIT
}

adding_installed_db() {
	local folder="$MANAGER_INSTALLED/$PKG_NAME"
	mkdir -p "$folder"

	echo "$PKG_VER" > "$folder/version"
	echo "$PKG_URL" > "$folder/url"

	if [ -n "$PKG_DEPENDENCIES" ]; then
		# echo "$PKG_DEPENDENCIES" | sed 's/\(.*\)/- \1/g' | tr '\n' '\n' > "$folder/dependencies"
		echo "$PKG_DEPENDENCIES" > "$folder/dependencies"
	else
		touch "$folder/dependencies"
	fi

	echo "$(cat "$TMP_PATH_FILES")" > "$folder/paths" &&
	rm -f $TMP_PATH_FILES
}


cleanup() {
	msg "Cleaning up temporary files.."

	if [ "$PREFIX" != "/usr" ] && [ "$PREFIX" != "/opt" ]; then
		 msg2 "Skipping removal of $PREFIX, it contains important files"
	 else
		 if [ -d "$PREFIX" ]; then
			 msg2 "Removing temporary prefix directory: $PREFIX"
			 rm -rf "$PREFIX" && msg "Removed temporary prefix directory"
		 fi
	fi

	if [ -n "$TMP_PATH_FILES" ]; then
		rm -f "$TMP_PATH_FILES" && msg2 "Removed temporary file $TMP_PATH_FILES"
	fi

	if [ -d "$MANAGER_ARCHIVES/$PKG_NAME" ]; then
		rm -rf "$MANAGER_ARCHIVES/$PKG_NAME" && msg2 "Removed package archive directory: $MANAGER_ARCHIVES/$PKG_NAME"
	fi

	msg "Cleanup completed."
}
