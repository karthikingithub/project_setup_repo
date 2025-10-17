#!/bin/ksh

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

PROJECT_PATH=""
LOG_BASE_DIR=""
LOG_FILE=""

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

color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red()   { tput setaf 1; print "$1"; tput sgr0; }
color_cyan()  { tput setaf 6; print "$1"; tput sgr0; }

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

check_git_repo() {
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        log_message ERROR "No .git directory in $PROJECT_PATH"
        color_red "ERROR: Not a Git repo! Exiting."
        exit 1
    fi
}

show_local_branches() {
    color_cyan "Available branches:"
    git -C "$PROJECT_PATH" branch -a
}

show_branch_log() {
    branch="$1"
    color_cyan "Recent commits in branch $branch:"
    git -C "$PROJECT_PATH" log -n 5 --pretty=format:'%h | %an | %ad | %s' --date=short
}

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

main() {
    if [ "$#" -lt 1 ]; then
        color_red "Usage: $0 <path_to_project>"
        exit 1
    fi

    load_config

    PROJECT_PATH="$1"
	
	PROJECT_NAME=$(basename "$PROJECT_PATH")
	SCRIPT_NAME=$(basename $0)
	SCRIPT_NAME=${SCRIPT_NAME%.*}
	
	LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"
	mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
	LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting git checkout for $PROJECT_PATH"
    check_git_repo

    show_local_branches
    color_cyan "Enter target branch to checkout (leave blank for current branch):"
    read branch_name
    branch_name=$(echo "$branch_name" | xargs)

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
    if [ "$branch_name" = "$current_branch" ]; then
        status=$(git -C "$PROJECT_PATH" status --porcelain)
        remote_status=$(git -C "$PROJECT_PATH" status | grep "up to date" | wc -l)
        if [ -z "$status" ] && [ "$remote_status" -ne 0 ]; then
            color_green "Already on branch '$current_branch' and working tree is clean/up to date!"
            log_message INFO "Already up to date. No changes."
            exit 0
        fi
    fi

    untracked_files=$(git -C "$PROJECT_PATH" ls-files --others --exclude-standard)
    if [ -n "$untracked_files" ]; then
        color_cyan "Note: These new/untracked files will remain after checkout:"
        print "$untracked_files"
    fi

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

    if [ "$checkout_status" -eq 0 ]; then
        # Try to pop stash if any
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

main "$@"
