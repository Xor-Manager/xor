#!/usr/bin/env bash

source /opt/xor/core/config.sh
source "$MANAGER_REPOSITORY/$repo_name/$PKG_NAME/XORBUILD"

pushd "$TMP_SOURCE_FOLDER/$FILE_NAME"

if declare
