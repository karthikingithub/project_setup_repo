#!/bin/ksh

# Script Name: git_checkout.sh
# Purpose: 
#   This script automates the process of checking out a Git branch for a given project directory.
#   It performs validation to ensure the directory is a Git repo, lists available branches,
#   allows the user to select a target branch, safely handles uncommitted changes via stashing,
#   and falls back to 'main' or 'master' if the requested branch does not exist.
#   All operations are logged with timestamps and color-coded terminal output for clarity.
#
# Usage:
#   ./git_checkout.sh /path/to/git/project
#
# Requirements:
#   - A configuration file at $HOME/config.env defining LOG_BASE_DIR must exist.
#   - The script must be run on a Unix-like system with ksh shell and git installed.
#
# Author:
#   Karthik KN
# Date:
#   [10/17/2025]

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

PROJECT_PATH=""
LOG_BASE_DIR=""
LOG_FILE=""

# Function to load environment configurations such as LOG_BASE_DIR from $HOME/config.env
load_config() {
    if [ ! -f "$HOME/config.env" ]; then
        print "ERROR: Config file $HOME/config.env missing. Cannot proceed."
        exit 1
    fi
    
    # Source the config file
    . "$HOME/config.env"
    
    if [ -z "$LOG_BASE_DIR" ]; then
        print "ERROR: LOG_BASE_DIR not set in config."
        exit 1
    fi
}

# Color output helpers for improved terminal readability
color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red()   { tput setaf 1; print "$1"; tput sgr0; }
color_cyan()  { tput setaf 6; print "$1"; tput sgr0; }

# Logging function to write timestamped messages to the log file
# Logs are categorized by levels: SUCCESS (green), ERROR (red), INFO (cyan)
log_message() {
    level=$1
    shift
    msg=$*
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    print "$timestamp [$level] $msg" >> "$LOG_FILE"
    
    case "$level" in
        SUCCESS) color_green "$msg" ;;
        ERROR)   color_red "$msg" ;;
        INFO)    color_cyan "$msg" ;;
        *)       print "$msg" ;;
    esac
}

# Check that the given project directory is a valid Git repository by looking for .git folder
check_git_repo() {
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        log_message ERROR "No .git directory in $PROJECT_PATH"
        color_red "ERROR: Not a Git repo! Exiting."
        exit 1
    fi
}

# Display list of local and remote branches available in the repository
show_local_branches() {
    color_cyan "Available branches:"
    git -C "$PROJECT_PATH" branch -a
}

# Display short recent commit logs for the given branch to provide context after checkout
show_branch_log() {
    branch="$1"
    color_cyan "Recent commits in branch $branch:"
    git -C "$PROJECT_PATH" log -n 5 --pretty=format:'%h | %an | %ad | %s' --date=short
}

# Perform git checkout for the specified branch, logging success or failure
checkout_branch() {
    branch="$1"
    git -C "$PROJECT_PATH" checkout "$branch"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Checked out branch: $branch"
        color_green "Checked out branch: $branch"
        show_branch_log "$branch"
        return 0
    else
        log_message ERROR "Failed to checkout branch: $branch"
        color_red "Checkout failed for branch: $branch"
        return 1
    fi
}

# Checkout specified branch if exists; if not, fallback to 'main' or 'master'
checkout_branch_with_fallback() {
    branch="$1"
    git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$branch"
    if [ $? -eq 0 ]; then
        checkout_branch "$branch"
        return $?
    fi

    color_red "Branch '$branch' does not exist."

    fallback=""
    for candidate in "main" "master"; do
        git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$candidate"
        if [ $? -eq 0 ]; then
            fallback=$candidate
            break
        fi
    done

    if [ -n "$fallback" ]; then
        color_cyan "Falling back to branch: $fallback"
        checkout_branch "$fallback"
        return $?
    else
        color_red "Neither 'main' nor 'master' branch found. Cannot checkout."
        log_message ERROR "No fallback branch (main/master) found."
        exit 1
    fi
}

# Main script workflow
main() {
    if [ "$#" -lt 1 ]; then
        color_red "Usage: $0 <git_project_path>"
        exit 1
    fi

    load_config

    PROJECT_PATH="$1"
    PROJECT_NAME=$(basename "$PROJECT_PATH")
    SCRIPT_NAME=$(basename $0)
    SCRIPT_NAME=${SCRIPT_NAME%.*}
    LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"

    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }

    # Create a timestamped log file for this execution
    LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting git checkout for $PROJECT_PATH"

    check_git_repo

    show_local_branches

    # Prompt user to enter the branch name to checkout, defaults to current if left blank
    color_cyan "Enter target branch to checkout (leave blank for current branch):"
    read branch_name
    branch_name=$(echo "$branch_name" | xargs)  # Trim whitespace

    if [ -z "$branch_name" ]; then
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD 2>/dev/null)
        if [ -z "$branch_name" ]; then
            branch_name="master"
            color_cyan "No current branch detected, defaulting to 'master'."
        else
            color_cyan "No input given, defaulting to current branch: $branch_name"
        fi
    fi

    current_branch=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD 2>/dev/null)

    # If already on the requested branch and working tree clean and up to date, exit early
    if [ "$branch_name" = "$current_branch" ]; then
        status=$(git -C "$PROJECT_PATH" status --porcelain)
        remote_status=$(git -C "$PROJECT_PATH" status | grep "up to date" | wc -l)
        if [ -z "$status" ] && [ "$remote_status" -ne 0 ]; then
            color_green "Already on branch '$current_branch' and working tree is clean/up to date!"
            log_message INFO "Already up to date. No changes."
            exit 0
        fi
    fi

    # Show untracked files if any
    untracked_files=$(git -C "$PROJECT_PATH" ls-files --others --exclude-standard)
    if [ -n "$untracked_files" ]; then
        color_cyan "Note: These new/untracked files will remain after checkout:"
        print "$untracked_files"
    fi

    # If there are unstaged or uncommitted changes, display them and attempt to stash before checkout
    dirty_status=$(git -C "$PROJECT_PATH" status --porcelain)
    if [ -n "$dirty_status" ]; then
        color_cyan "You have unstaged or uncommitted changes to tracked files:"
        git -C "$PROJECT_PATH" status --short
        color_cyan "Preview diff before switching branch:"
        git -C "$PROJECT_PATH" diff --stat
        color_cyan "Attempting to stash changes before checkout..."
        git -C "$PROJECT_PATH" stash push -m "autostash before branch switch" >/dev/null
        if [ $? -eq 0 ]; then
            color_green "Local changes stashed successfully."
        else
            color_red "Failed to stash local changes. Aborting checkout."
            log_message ERROR "Stash failed; aborting checkout"
            exit 1
        fi
    fi

    checkout_branch_with_fallback "$branch_name"
    checkout_status=$?

    # If checkout succeeded, try to apply stashed changes back, if any
    if [ "$checkout_status" -eq 0 ]; then
        stash_list=$(git -C "$PROJECT_PATH" stash list)
        echo "$stash_list" | grep -q "autostash before branch switch"
        if [ $? -eq 0 ]; then
            color_cyan "Applying previously stashed changes..."
            git -C "$PROJECT_PATH" stash pop
            if [ $? -eq 0 ]; then
                color_green "Stash applied cleanly."
            else
                color_red "Stash apply had conflicts; please resolve manually."
                log_message ERROR "Stash apply conflicts"
            fi
        fi
    fi

    log_message SUCCESS "Completed git checkout for $PROJECT_PATH"
}

# Invoke main with all passed arguments
main "$@"
