#!/usr/bin/bash
set -e

source ./config.sh
source ./messages.sh

PKG_NAME=$1
PKG_VER=$2

#First (main)
search_repositories() {
	PKG_NAME=$1

	result=$(find "$MANAGER_REPOSITORY" -type d -name "$PKG_NAME" | head -n 1)

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
	source "$MANAGER_REPOSITORY/$PKG_NAME/build.sh"

	if [ -z "$PKG_DEPENDENCIES" ]; then

		msg3 "No dependencies for $PKG_NAME. Want to install ? (Y/n)"

		read -r answer
		answer=${answer:-"y"}
		if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
			download
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
					bash ./xor install "$dep"
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
		sudo mkdir -p "$MANAGER_ARCHIVES/$PKG_NAME"
	fi


	FILE_EXT=$(basename "$PKG_URL" | sed 's/.*\(\.tar\..*\)/\1/')
	FILE_NAME="$PKG_NAME-$PKG_VER"

	if [ ! -f "$MANAGER_ARCHIVES/$PKG_NAME/$FILE_NAME$FILE_EXT" ]; then
		pushd "$MANAGER_ARCHIVES/$PKG_NAME"

			msg2 "Unpacking $FILE_NAME"
			sudo wget --waitretry=1 -O "$FILE_NAME$FILE_EXT" "$PKG_URL"

		popd
	fi

	unpack
}

unpack() {
	pushd "$MANAGER_ARCHIVES/$PKG_NAME"
		msg2 "Unpacking $FILE_NAME"
		sudo tar xf "$FILE_NAME$FILE_EXT" || { msgerr "Error unpacking $FILE_NAME"; exit 1; }

		FILE_NAME=$(ls -td */ | head -n 1 | tr -d '/')

		msg "Creating build folder"
		sudo mkdir -p "$FILE_NAME/build"
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
	local log_file="$MANAGER_DB/paths/$PKG_NAME"

	if [ ! -d "$src_dir" ]; then
		msgerr "Source directory $src_dir does not exist!"
		return 1
	fi

	sudo mkdir -p "$dest_dir"

	for file in "$src_dir"/*; do
		if [ -f "$file" ]; then
			dest_file="$dest_dir/$(basename "$file")"

			# echo "Installing $file to $dest_file"
			sudo install -Dm755 "$file" "$dest_file" && echo "$dest_file" | sudo tee -a "$log_file" > /dev/null
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

	adding_installed_db
	remove_archives
}

remove_archives() {
	sudo rm -rf "$MANAGER_ARCHIVES/$PKG_NAME/*"
	echo $PREFIX
}

adding_installed_db() {

	DEPENDENCIES=$(echo "$PKG_DEPENDENCIES" | sed 's/\(.*\)/- \1/g' | tr '\n' '\n')

	sudo tee "$MANAGER_DB/installed/$PKG_NAME" > /dev/null <<- EOF
	Package: $PKG_NAME
	Version: $PKG_VER
	Dependencies:
		$(echo "$PKG_DEPENDENCIES" | sed 's/^/- /')
	Url: $PKG_URL
	EOF
}
