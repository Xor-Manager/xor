#!/usr/bin/env bash
set -e

source ./config.sh
source ./messages.sh

list_repository () {
    if [ -n "$1" ]; then
        msg3 "Searching for package: $1"
        pushd "$MANAGER_REPOSITORY" > /dev/null
        find . -type d -iname "*$1*" -exec basename {} \; | nl -s ". "
        popd > /dev/null
    else
        msg3 "Packages on repository: "
        pushd "$MANAGER_REPOSITORY" > /dev/null
        find . -type d -exec basename {} \; | grep -v '^\.$' | nl -s ". "
        popd > /dev/null
    fi
}

list_installed_packages() {
    msg3 "Installed packages with versions:"
    for pkg in "$MANAGER_DB/installed"/*; do
        if [ -f "$pkg" ]; then

            pkg_name=$(basename "$pkg")
            pkg_version=$(grep -i "Version" "$pkg" | awk -F": " '{print $2}')
            echo "$pkg_name - $pkg_version"

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

