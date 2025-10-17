#!/bin/ksh

# Usage:
#   ./cleanup_project.sh /target/path project_name
#
# Korn shell script to delete a full project directory structure,
# with confirmation prompt before deleting anything. Logs all actions.

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}


PROJECT_PATH=""
PROJECT_NAME=""
LOG_FILE=""

# ------ Color Helper Functions ------
color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red() { tput setaf 1; print "$1"; tput sgr0; }
color_cyan() { tput setaf 6; print "$1"; tput sgr0; }

# ------ Logging Function ------
log_message() {
    level=$1
    shift
    msg=$*
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    line="$timestamp [$level] $msg"
    print "$line" >> "$LOG_FILE"

    case "$level" in
        SUCCESS) color_green "$msg" ;;
        ERROR) color_red "$msg" ;;
        INFO) color_cyan "$msg" ;;
        *) print "$msg";;
    esac
}

# ------ Confirmation Prompt ------
# Asks the user to confirm deletion. If not 'yes', aborts.
confirm_deletion() {
    dir_path="$1"
    print ""
    color_red "WARNING: This will permanently delete the directory and everything inside:"
    color_cyan "         $dir_path"
    print "Are you sure you want to proceed? Type 'yes' to confirm deletion:"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [ "$answer" != "yes" ]; then
        log_message INFO "Cleanup cancelled by user."
        color_cyan "Operation cancelled."
        exit 0
    fi
}

load_config() {
    if [ ! -f "$HOME/config.env" ]; then
        print "ERROR: Config file $HOME/config.env missing. Cannot proceed."
        exit 1
    fi
    . "$HOME/config.env"
    if [ -z "$LOG_BASE_DIR" ]; then
        print "ERROR: LOG_BASE_DIR not set in config."
        exit 1
    fi
}

# ------ Cleanup Function ------
cleanup_project_dir() {
    dir_path="$1"

    if [ -d "$dir_path" ]; then
        log_message INFO "Project directory found: $dir_path"
        confirm_deletion "$dir_path"

        rm -rf "$dir_path"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Cleaned up and deleted $dir_path and all subdirectories/files."
        else
            log_message ERROR "Failed to delete $dir_path. Check permissions or running processes using files."
            exit 1
        fi
    else
        log_message ERROR "Directory $dir_path does not exist. Nothing to clean up."
        exit 1
    fi
}

# ------ Main Function ------
main() {
    if [ "$#" -ne 2 ]; then
        color_red "Usage: $0 <target_path> <project_name>"
        exit 1
    fi

    target_path="$1"
    project_name="$2"
    PROJECT_PATH="${target_path%/}/$project_name"
    PROJECT_NAME="$project_name"
	
	load_config
	
	LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"
	mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
	LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting cleanup for project: $PROJECT_NAME at $PROJECT_PATH"

    cleanup_project_dir "$PROJECT_PATH"

    log_message SUCCESS "Cleanup finished for $PROJECT_PATH."
    color_green "Cleanup completed successfully!"
}

main "$@"
