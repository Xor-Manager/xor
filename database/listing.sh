#!/usr/bin/env bash
set -e

source $(dirname "$0")/../core/config.sh
source $(dirname "$0")/../core/messages.sh

list_installed_packages() {
    msg3 "Installed packages with versions:"
    for pkg in "$MANAGER_INSTALLED"/*; do
        if [ -d "$pkg" ]; then

            pkg_name=$(basename "$pkg")
            pkg_version="$(cat "$pkg/version")"

            echo -e "$pkg_name $GREEN[$pkg_version]$RESET"
        fi
    done
}

show_dependencies() {
    if [ -n "$1" ]; then
        local pkg_file="$MANAGER_DB/installed/$1"

        if [ -f "$pkg_file" ]; then
            dependencies=$(awk '/Dependencies:/ {flag=1; next} /Url:/ {flag=0} flag' "$pkg_file" | sed '/^$/d' | sed 's/^- //')

            echo -e "Dependencies for package: ${GREEN}$1${RESET}"

            if [ -n "$dependencies" ]; then
                echo "$dependencies" | sed 's/^/- /'
            else
                echo "  No dependencies."
            fi
        else
            msgerr "Package $1 not found in the installed database."
        fi
    else
        echo "All installed packages and their dependencies:"

        for pkg in "$MANAGER_DB/installed"/*; do
            if [ -f "$pkg" ]; then
                local pkg_name
                pkg_name=$(basename "$pkg")

                dependencies=$(awk '/Dependencies:/ {flag=1; next} /Url:/ {flag=0} flag' "$pkg" | sed '/^$/d' | sed 's/^- //')

                echo -e "\n${GREEN}Package:${RESET} $pkg_name"
                
                if [ -n "$dependencies" ]; then
                    echo "Dependencies:"
                    echo "$dependencies" | sed 's/^/- /'
                else
                    echo "Dependencies: No dependencies."
                fi
            fi
        done
    fi
}

