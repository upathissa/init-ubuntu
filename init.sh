#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this script as root.\n' >&2
    exit 1
fi

# Check dependencies before making any changes.
for command in adduser usermod rsync ufw getent chmod; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command is missing: %s\n' "$command" >&2
        exit 1
    fi
done

root_home=$(getent passwd root | cut -d: -f6)
if [[ ! -d "$root_home/.ssh" ]]; then
    printf 'Root SSH directory was not found: %s/.ssh\n' "$root_home" >&2
    exit 1
fi

while true; do
    read -r -p 'Enter the new username: ' username

    # Use a conservative Ubuntu-compatible username format.
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        printf 'Use 1–32 characters: start with a lowercase letter, then use lowercase letters, digits, underscores or hyphens.\n' >&2
    elif getent passwd "$username" >/dev/null; then
        printf 'User "%s" already exists. Choose a new username.\n' "$username" >&2
    elif getent group "$username" >/dev/null; then
        printf 'Group "%s" already exists. Choose a new username.\n' "$username" >&2
    else
        break
    fi
done

# adduser prompts for the new user's password and optional account details.
adduser "$username"
usermod -aG sudo "$username"

user_home=$(getent passwd "$username" | cut -d: -f6)
rsync --archive --chown="$username:$username" -- "$root_home/.ssh" "$user_home/"
chmod -R go-rwx "$user_home/.ssh"
chmod 700 "$user_home/.ssh"

ufw allow OpenSSH

printf '\nCreated sudo user "%s" and copied root SSH files to %s/.ssh.\n' "$username" "$user_home"
printf 'OpenSSH is allowed in UFW. This script does not enable the firewall.\n'
printf 'Keep this root session open until you verify SSH login as "%s" from another terminal.\n' "$username"
