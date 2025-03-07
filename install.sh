#!/usr/bin/env bash
set -e

BINDIR="/usr/bin"
LIBDIR="/usr/lib/xor"
CONFDIR="/etc/xor"

install -d "$BINDIR"

install -d "$CONFDIR"

install -d "$LIBDIR"
install -d "$LIBDIR/lib" "$LIBDIR/src" "$LIBDIR/db"

install -m644 ./lib/* "$LIBDIR/lib"
install -m644 ./src/* "$LIBDIR/src"
install -m644 ./db/* "$LIBDIR/db"

install -m644 ./mirrorlist "$CONFDIR/"

install -m755 ./xor "$BINDIR"
