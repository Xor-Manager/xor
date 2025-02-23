#!/usr/bin/env bash

export LC_ALL=C

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m"  # Reseta para a cor padrão

interrupt(){
	echo
	exit 1
}

msg() {
	echo -e " ==> $1"
}

msg2() {
	echo -e "${BLUE} -> $1 ${RESET}"
}

msg3() {
	echo -e "${GREEN} -> $1 ${RESET}"
}

msgerr() {
	echo -e "${RED} ==> ERROR: $1 ${RESET}" >&2
}

msgwarn() {
	echo -e "${YELLOW} ==> WARNING: $1 ${RESET}">&2
}
