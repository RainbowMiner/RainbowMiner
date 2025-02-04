#!/usr/bin/env bash

# Usage: ./set_permissions.sh /path/to/directory [username]

# Check if the directory is provided
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/directory [username]"
  exit 1
fi

# Set the username to the second argument or default to 'root'
USER_NAME=${2:-root}

# Check if the provided path is a directory
if [ ! -d "$1" ]; then
  echo "Error: '$1' is not a directory."
  exit 1
fi

# Recursively set permissions only for files/directories owned by the specified user
find "$1" -mindepth 1 -user "$USER_NAME" -type f -exec chmod 0666 {} \;
find "$1" -mindepth 1 -user "$USER_NAME" -type d -exec chmod 0777 {} \;

echo "Permissions updated successfully for user '$USER_NAME'."
