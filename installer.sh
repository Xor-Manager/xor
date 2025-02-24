#!/usr/bin/bash
set -e

source ./config.sh
source ./messages.sh

source ./repositories

PKG_NAME=$1
PKG_VER=$2


#First (main)
check_already_installed() {
	PKG_NAME=$1

	if [ -d "$MANAGER_DB/installed/$PKG_NAME" ]; then
		msg "Package $PKG_NAME is already installed."
		interrupt
	fi
	check_repositories
}

check_repositories() {
	result=$(search_repositories "$PKG_NAME" | head -n 1)
	echo $result

	if [ -n "$result" ]; then
		echo "Package found: $result"
		echo ""

		check_dependencies
	else
		msgerr "Package not found: $PKG_NAME"
		interrupt
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
	echo "$PKG_DEPENDENCIES" | tr ' ' '\n' | sed '/^$/d' | sed 's/^/   - /' | column -c 80
	echo ""


	if [ "$INTERACTIVE_MODE" == "true" ]; then

		for dep in $PKG_DEPENDENCIES; do
			if [ ! -f "$MANAGER_DB/installed/$dep" ]; then
				msgwarn "Dependencie $dep not found. Want to install ? (Y/n)"

				read -r answer
				answer=${answer:-"y"}
				if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
					if [ ! -d "$MANAGER_INSTALLED/$dep"]; then
						bash ./xor install "$dep"
					fi
				else
					msgerr "Dependencie $dep not installed. The package can not work correcly."
				fi
			else
				msg "Dependencie $dep already installed."
			fi
		done
	else
		missing_deps=()
		for dep in $PKG_DEPENDENCIES; do
			if [ ! -f "$MANAGER_DB/installed/$dep" ]; then
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
				# bash "$0" "$dep"
				bash ./xor install "$dep"
			done
		fi
	fi

	download
}

download() {
	msg "Sourcing repository $PKG_NAME"

	if [ ! -d "$MANAGER_ARCHIVES/$PKG_NAME" ]; then
		mkdir -p "$MANAGER_ARCHIVES/$PKG_NAME"
	fi


	FILE_EXT=$(basename "$PKG_URL" | sed 's/.*\(\.tar\..*\)/\1/')
	FILE_NAME="$PKG_NAME-$PKG_VER"

	if [ ! -f "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" ]; then
		msg2 "Downloading $FILE_NAME"

		wget --waitretry=1 -O "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" "$PKG_URL"
	else
		msg "Package $PKG_NAME already downloaded."
	fi

	unpack
}

unpack() {
	pushd "$MANAGER_ARCHIVES/$PKG_NAME"
		msg2 "Unpacking $FILE_NAME"
		tar xf "$FILE_NAME$FILE_EXT" || { msgerr "Error unpacking $FILE_NAME"; exit 1; }

		FILE_NAME=$(ls -td */ | head -n 1 | tr -d '/')

		msg "Creating build folder"
		mkdir -p "$FILE_NAME/build"
	popd

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

	# local log_file="$MANAGER_DB/paths/$PKG_NAME"
	PATHS_FILE="/tmp/$PKG_NAME"

	if [ ! -d "$src_dir" ]; then
		msgerr "Source directory $src_dir does not exist!"
		return 1
	fi

	mkdir -p "$dest_dir"

	for file in "$src_dir"/*; do
		if [ -f "$file" ]; then
			dest_file="$dest_dir/$(basename "$file")"

			# echo "Installing $file to $dest_file"
			install -Dm755 "$file" "$dest_file" && echo "$dest_file" | tee -a "$PATHS_FILE" > /dev/null
			msg2 "Installed: $dest_file"

		elif [ -d "$file" ]; then
			new_dest_dir="$dest_dir/$(basename "$file")"
			install_and_log "$file" "$new_dest_dir" "$package_name"
		fi
	done
}

installing() {
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

	adding_installed_db
	remove_archives
}

remove_archives() {
	rm -rf "$MANAGER_ARCHIVES/$PKG_NAME/*"
	echo $PREFIX
}

cleanup() {
	rm -rf "$MANAGER_ARCHIVES/$PKG_NAME/*"
	rm -rf "$MANAGER_ARCHIVES/$PKG_NAME/*"
}

adding_installed_db() {
	local folder="$MANAGER_INSTALLED/$PKG_NAME"
	mkdir -p "$folder"

	echo "$PKG_VER" > "$folder/version"
	echo "$PKG_URL" > "$folder/url"

	if [ -n "$PKG_DEPENDENCIES" ]; then
		echo "$PKG_DEPENDENCIES" | sed 's/\(.*\)/- \1/g' | tr '\n' '\n' > "$folder/dependencies"
	else
		touch "$folder/dependencies"
	fi

	echo "$(cat "$PATHS_FILE")" > "$folder/paths" &&
	rm $PATHS_FILE
}
