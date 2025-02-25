#!/usr/bin/env bash
set -e

source ../core/config.sh
source ../core/messages.sh

source ../database/repositories


list_repository() {
	result=$(search_repositories "*$1*")

	if [ -n "$1" ]; then
		msg3 "Searching for package: $1"

		echo "$result" | nl -s ". "
	else
		msg3 "Packages on repository: "

		echo "$result" | grep -v '^\.$' | nl -s ". "
	fi
}

# list_installed() {
# }


# list_dependencies() {
# }
