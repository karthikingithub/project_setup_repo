#!/bin/ksh

# cleanup_old_logs.sh
#
# Purpose:
#   Safely clean up log files and folders under the centralized log directory.
#   - Deletes all files older than 60 days recursively under $LOG_BASE_DIR.
#   - Detects empty directories with no activity for 60+ days.
#   - Prompts user to delete such stale empty directories.
#   - Logs each deletion operation and user decisions for audit and traceability.
#
# Usage:
#   ksh cleanup_old_logs.sh
#
# Requirements:
#   - $HOME/config.env must exist and define LOG_BASE_DIR.
#   - Script must have sufficient permissions to delete files and directories under LOG_BASE_DIR.

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

LOG_BASE_DIR=""
LOG_FILE=""

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

color_green() { tput setaf 2; echo "$1"; tput sgr0; }
color_red()   { tput setaf 1; echo "$1"; tput sgr0; }
color_cyan()  { tput setaf 6; echo "$1"; tput sgr0; }

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

delete_file() {
    file="$1"
    rm -f "$file"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Deleted file: $file"
    else
        log_message ERROR "Failed to delete file: $file"
    fi
}

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

main() {
    load_config

    LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"
    mkdir -p "$LOG_DIR" || { echo "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
    LOG_FILE="${LOG_DIR}/cleanup_old_logs_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting cleanup of files older than 60 days under $LOG_BASE_DIR"

    # Find all files older than 60 days and delete each, logging each action
    old_files=$(find "$LOG_BASE_DIR" -type f -mtime +60)
    if [ -z "$old_files" ]; then
        log_message INFO "No files older than 60 days found under $LOG_BASE_DIR."
    else
        echo "$old_files" | while read -r file; do
            delete_file "$file"
        done
    fi

    # Find all empty directories; check if last modified 60+ days ago and prompt user
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

main "$@"
