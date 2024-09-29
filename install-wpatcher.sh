#!/bin/bash

##
# Install wpatcher.sh
#
SCRIPT_URL=https://raw.githubusercontent.com/headwalluk/wpatcher/refs/heads/main/wpatch.sh
LOCAL_FILE_NAME="${HOME}"/wpatch
TARGET_BIN_DIR=/usr/local/bin
TARGET_BIN=/usr/local/bin/wpatch

curl -o "${LOCAL_FILE_NAME}" "${SCRIPT_URL}"
if [ $? -ne 0 ] || [ ! -f "${LOCAL_FILE_NAME}" ]; then
  echo "Failed to download wpatch from github"
  exit 1
fi

echo "make ${LOCAL_FILE_NAME} executable"
chmod +x "${LOCAL_FILE_NAME}"

echo "move ${LOCAL_FILE_NAME} to ${TARGET_BIN}"
sudo mv "${LOCAL_FILE_NAME}" "${TARGET_BIN}"
if [ $? -ne 0 ] || [ ! -f "${TARGET_BIN}" ]; then
  echo "Failed to move ${LOCAL_FILE_NAME} to ${TARGET_BIN}"
  exit 1
fi

echo "wpatcher installed successfully"
echo "run 'wpatch --help' for usage information"
echo "run 'wpatch update to install the latest patch definitions at any time"
