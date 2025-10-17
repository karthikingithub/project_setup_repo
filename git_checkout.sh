#!/bin/ksh

##############################################################################
# Script Name: git_checkout.sh
#
# Purpose:
#   Automate git branch checkout for a given project directory with support
#   for either a GitHub URL or a local path. If a GitHub URL is provided,
#   the repository is cloned into the specified local directory if not already present.
#
# Features:
#   - Detects whether input is a Git URL or local path
#   - Clones repo if URL given, otherwise works on local path
#   - Checks out specified branch (with fallback to main/master if branch missing)
#   - Safely stashes and reapplies uncommitted changes during checkout
#   - Interactive prompt to display recent commit summaries including files changed
#   - Logs operations with timestamps and color-coded terminal output
#
# Usage:
#   ksh git_checkout.sh <github_repo_url> <local_target_path>
#   OR
#   ksh git_checkout.sh <local_git_repo_path>
#
# Requirements:
#   - ksh shell, git installed on Unix-like system
#   - Configuration file at $HOME/config.env with LOG_BASE_DIR defined
#
# Author: Karthik KN
# Date: 2025-10-17
##############################################################################

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

PROJECT_PATH=""
LOG_BASE_DIR=""
LOG_FILE=""

# Helper: check if string is a git URL (GitHub)
is_git_url() {
  [[ "$1" =~ ^(https:\/\/github\.com\/|git@github\.com:) ]] && return 0 || return 1
}

# Load config (expects LOG_BASE_DIR defined in $HOME/config.env)
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

# Color output helpers for terminal readability
color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red() { tput setaf 1; print "$1"; tput sgr0; }
color_cyan() { tput setaf 6; print "$1"; tput sgr0; }

# Logging function
# Logs messages with timestamp and levels to LOG_FILE and colors output accordingly
log_message() {
  level=$1
  shift
  msg=$*
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  print "$timestamp [$level] $msg" >> "$LOG_FILE"
  case "$level" in
    SUCCESS) color_green "$msg" ;;
    ERROR) color_red "$msg" ;;
    INFO) color_cyan "$msg" ;;
    *) print "$msg" ;;
  esac
}

# Validate that PROJECT_PATH is a git repository
check_git_repo() {
  if [ ! -d "$PROJECT_PATH/.git" ]; then
    log_message ERROR "No .git directory in $PROJECT_PATH"
    color_red "ERROR: Not a Git repo! Exiting."
    exit 1
  fi
}

# Display all local and remote branches
show_local_branches() {
  color_cyan "Available branches:"
  git -C "$PROJECT_PATH" branch -a
}

# Display recent commit logs for a branch
show_branch_log() {
  branch="$1"
  color_cyan "Recent commits in branch $branch:"
  git -C "$PROJECT_PATH" log -n 5 --pretty=format:'%h | %an | %ad | %s' --date=short
}

# Checkout specified branch, logging success or failure
# Removed recent commit print here to avoid duplicate output
checkout_branch() {
  branch="$1"
  git -C "$PROJECT_PATH" checkout "$branch" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    log_message SUCCESS "Checked out branch: $branch"
    color_green "Checked out branch: $branch"
    return 0
  else
    log_message ERROR "Failed to checkout branch: $branch"
    color_red "Checkout failed for branch: $branch"
    return 1
  fi
}

# Attempt to checkout given branch, fall back to main/master if missing
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

# Interactive display of recent commit summaries with file changes
show_recent_changes() {
  cd "$PROJECT_PATH" || { color_red "Cannot access $PROJECT_PATH"; return 1; }
  num_commits=""
  while true; do
    color_cyan "How many recent commits do you want to see? (default 5, 'exit' to cancel):"
    read num_commits
    if [ "$num_commits" = "exit" ]; then
      color_red "Cancelled by user."
      return 1
    fi
    if [ -z "$num_commits" ]; then
      num_commits=5
      break
    elif [[ "$num_commits" =~ ^[0-9]+$ ]]; then
      break
    else
      color_red "Invalid input. Please enter a positive number or 'exit'."
    fi
  done

  repo_name=$(basename "$PROJECT_PATH")
  w_project=18; w_commit=10; w_author=14; w_date=10; w_message=34; w_files=40

  # Print header
  printf "%-${w_project}s | %-${w_commit}s | %-${w_author}s | %-${w_date}s | %-${w_message}s | %-${w_files}s\n" \
    "Project" "Commit" "Author" "Date" "Message" "Files Changed"
  # Print underline separator
  printf "%-${w_project}s | %-${w_commit}s | %-${w_author}s | %-${w_date}s | %-${w_message}s | %-${w_files}s\n" \
    "$(printf '%*s' $w_project | tr ' ' '-')" \
    "$(printf '%*s' $w_commit | tr ' ' '-')" \
    "$(printf '%*s' $w_author | tr ' ' '-')" \
    "$(printf '%*s' $w_date | tr ' ' '-')" \
    "$(printf '%*s' $w_message | tr ' ' '-')" \
    "$(printf '%*s' $w_files | tr ' ' '-')"

  git log -n "$num_commits" --pretty=format:"%h|%an|%ad|%s" --date=short |
  while IFS='|' read -r short_sha author date message; do
    files=$(git show --pretty="" --name-only "$short_sha" | paste -sd, -)
    t_message=$(echo "$message" | cut -c1-$w_message)
    [ "${#message}" -gt $w_message ] && t_message="${t_message}…"
    t_files=$(echo "$files" | cut -c1-$w_files)
    [ "${#files}" -gt $w_files ] && t_files="${t_files}…"

    # Print formatted commit line
    printf "%-${w_project}s | %-${w_commit}s | %-${w_author}s | %-${w_date}s | %-${w_message}s | %-${w_files}s\n" \
      "$repo_name" "$short_sha" "$author" "$date" "$t_message" "$t_files"
  done
}

# Main script workflow entry point
main() {
  # Argument parsing to handle Git URL + local path OR local path alone
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    color_red "Usage: $0 <github_repo_url_or_local_path> [local_path_to_checkout]"
    exit 1
  fi

  SRC=$1
  TARGET_PATH=""
  if [ $# -eq 2 ]; then
    TARGET_PATH=$2
  fi

  if is_git_url "$SRC"; then
    # Clone repo if it doesn't exist in target path
    if [ -z "$TARGET_PATH" ]; then
      color_red "Target path required when using a GitHub URL."
      exit 1
    fi
    repo_name=$(basename "$SRC" .git)
    clone_dir="$TARGET_PATH/$repo_name"
    if [ -d "$clone_dir/.git" ]; then
      print "Git repo already exists in $clone_dir, skipping clone."
    else
      print "Cloning repo $SRC into $clone_dir ..."
      mkdir -p "$TARGET_PATH"
      git clone "$SRC" "$clone_dir"
      if [ $? -ne 0 ]; then
        print "Error cloning repo. Exiting."
        exit 1
      fi
    fi
    PROJECT_PATH="$clone_dir"
  else
    # Treat first argument as local path
    if [ ! -d "$SRC" ]; then
      color_red "Local path $SRC does not exist."
      exit 1
    fi
    PROJECT_PATH="$SRC"
  fi

  # Load logging configuration
  load_config

  # Initialize logging
  PROJECT_NAME=$(basename "$PROJECT_PATH")
  LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"
  mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
  LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

  log_message INFO "Starting git checkout for $PROJECT_PATH"

  check_git_repo

  show_local_branches

  # Prompt for branch to checkout
  color_cyan "Enter target branch to checkout (leave blank for current branch):"
  read branch_name
  branch_name=$(echo "$branch_name" | xargs)

  # Default branch handling
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
  # Exit if branch is current and clean
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

  # Stash uncommitted changes if present
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

  # Checkout branch with fallback
  checkout_branch_with_fallback "$branch_name"
  checkout_status=$?

  # Apply stashed changes if any
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

  # Interactive prompt to show recent commit summaries, runs only once now
  while true; do
    color_cyan "Would you like to see recent commit summaries? (yes/no/exit):"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
      yes)
        show_recent_changes && break
        ;;
      no)
        break
        ;;
      exit)
        color_red "Exiting as requested by user."
        exit 0
        ;;
      *)
        color_red "Invalid input. Please enter yes, no, or exit."
        ;;
    esac
  done

  log_message SUCCESS "Completed git checkout for $PROJECT_PATH"
}

# Run main function with all parameters
main "$@"
