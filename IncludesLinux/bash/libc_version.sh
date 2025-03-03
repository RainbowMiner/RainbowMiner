#!/usr/bin/env bash

# Function to print error messages and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Try to get glibc version using `ldd`
if command -v ldd >/dev/null 2>&1; then
    version=$(ldd --version 2>/dev/null | sed -n '1s/[^0-9]*\([0-9]\+\.[0-9]\+\).*/\1/p')
    if [ -n "$version" ]; then
        echo "$version"
        exit 0
    fi
fi

# Fallback: Check libc.so.6 directly
if [ -f "/lib/libc.so.6" ]; then
    version=$(/lib/libc.so.6 2>&1 | sed -n 's/.*release version \([0-9]\+\.[0-9]\+\).*/\1/p')
    if [ -n "$version" ]; then
        echo "$version"
        exit 0
    fi
elif [ -f "/lib64/libc.so.6" ]; then
    version=$(/lib64/libc.so.6 2>&1 | sed -n 's/.*release version \([0-9]\+\.[0-9]\+\).*/\1/p')
    if [ -n "$version" ]; then
        echo "$version"
        exit 0
    fi
fi

# Fallback: Try `getconf`
if command -v getconf >/dev/null 2>&1; then
    version=$(getconf GNU_LIBC_VERSION 2>/dev/null | cut -d ' ' -f2)
    if [ -n "$version" ]; then
        echo "$version"
        exit 0
    fi
fi

# If everything fails, return an error
error_exit "Could not determine glibc version"
