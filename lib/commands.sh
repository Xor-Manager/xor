#!/usr/bin/env bash
set -e

LIBDIR="/usr/lib/xor"

source "$LIBDIR/lib/config.sh"
source "$LIBDIR/lib/messages.sh"

source "$LIBDIR/db/repositories"


list_repository() {
	result=$(search_repositories "*$1*")
	result2=()

	#for pkg in ${result[@]}; do
	#	local repo=$(find_pkg_repository "$pkg")
	#	#echo "$pkg [$repo]"
	#	result2+=$(echo "$pkg ["$repo"]")
	#done

	if [ -n "$1" ]; then
		msg3 "Searching for package: $1"

		result2=$(find_pkg_repository $result)

		echo "$result [$result2]" | nl -s ". "
	else
		msg3 "Packages on repository: "
 
		echo "$result" | grep -v '^\.$' | nl -s ". " | column -c 80
	fi
}

# list_installed() {
# }


# list_dependencies() {
# }
