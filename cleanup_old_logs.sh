#!/bin/ksh

# Script Name: cleanup_old_logs.sh
# Purpose:
#   Safely clean up log files and directories under the centralized log directory.
#   - Deletes all files older than 60 days recursively under the directory defined by $LOG_BASE_DIR.
#   - Finds empty directories with no activity for 60 or more days.
#   - Prompts the user to confirm deletion of such stale empty directories.
#   - Logs every deletion operation and user decision for audit and traceability.
#
# Usage:
#   ksh cleanup_old_logs.sh
#
# Requirements:
#   - $HOME/config.env must exist and define the LOG_BASE_DIR variable.
#   - The script must have sufficient permissions to delete files and directories under LOG_BASE_DIR.
#
# Author:
#   Karthik KN
# Date:
#   [10/17/2025]

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

LOG_BASE_DIR=""
LOG_FILE=""

# Load configuration environment, such as LOG_BASE_DIR, from user's config file
load_config() {
    if [ ! -f "$HOME/config.env" ]; then
        echo "ERROR: Config file $HOME/config.env missing. Cannot proceed."
        exit 1
    fi
    . "$HOME/config.env"
    if [ -z "$LOG_BASE_DIR" ]; then
        echo "ERROR: LOG_BASE_DIR not set in config."
        exit 1
    fi
}

# Color helper functions to display colored messages on terminal
color_green() { tput setaf 2; echo "$1"; tput sgr0; }
color_red()   { tput setaf 1; echo "$1"; tput sgr0; }
color_cyan()  { tput setaf 6; echo "$1"; tput sgr0; }

# Logging function to log messages with timestamp and severity level
log_message() {
    level=$1
    shift
    msg=$*
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        SUCCESS) color_green "$msg" ;;
        ERROR)   color_red "$msg" ;;
        INFO)    color_cyan "$msg" ;;
        *)       echo "$msg" ;;
    esac
}

# Deletes the specified file and logs success or failure
delete_file() {
    file="$1"
    rm -f "$file"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Deleted file: $file"
    else
        log_message ERROR "Failed to delete file: $file"
    fi
}

# Prompts the user to confirm deletion of an empty directory older than 60 days
prompt_delete_dir() {
    dir="$1"
    color_cyan "Directory $dir is empty and has had no file changes for 60 days."
    echo "Do you want to delete this directory? (yes/no)"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [ "$answer" = "yes" ]; then
        rm -rf "$dir"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Deleted empty directory $dir"
            color_green "Deleted directory $dir"
        else
            log_message ERROR "Failed to delete directory $dir"
            color_red "Failed to delete directory $dir"
        fi
    else
        log_message INFO "Skipped deletion of directory $dir"
        color_cyan "Skipped directory $dir"
    fi
}

# Main script execution function
main() {
    load_config
    LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"

    # Create log directory if not existing
    mkdir -p "$LOG_DIR" || { echo "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }

    LOG_FILE="${LOG_DIR}/cleanup_old_logs_$(date +%Y%m%d_%H%M%S).log"
    log_message INFO "Starting cleanup of files older than 60 days under $LOG_BASE_DIR"

    # Find all files older than 60 days and delete them, logging each deletion
    old_files=$(find "$LOG_BASE_DIR" -type f -mtime +60)
    if [ -z "$old_files" ]; then
        log_message INFO "No files older than 60 days found under $LOG_BASE_DIR."
    else
        echo "$old_files" | while read -r file; do
            delete_file "$file"
        done
    fi

    # Find all empty directories and check if last modified 60+ days ago
    empty_dirs=$(find "$LOG_BASE_DIR" -type d -empty)
    if [ -z "$empty_dirs" ]; then
        log_message INFO "No empty directories to check under $LOG_BASE_DIR."
    else
        echo "$empty_dirs" | while read -r dirpath; do
            last_mod=$(stat -c %Y "$dirpath" 2>/dev/null)
            curr_time=$(date +%s)
            age_days=$(( (curr_time - last_mod) / 86400 ))
            if [ "$age_days" -ge 60 ]; then
                prompt_delete_dir "$dirpath"
            fi
        done
    fi

    log_message INFO "Cleanup of old log files and empty directories completed."
}

# Start the script
main "$@"
