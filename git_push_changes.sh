#!/bin/ksh

# Usage:
#   ./git_push_changes.sh /path/to/project/project_name [branch]
#
# Interactive git add/commit/push script.
# Shows status, stages interactively, robust error handling, branch check,
# verifies push on GitHub using GITHUB_TOKEN env, logs all actions.

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log/${SCRIPT_NAME}"
mkdir -p "$LOG_BASE_DIR" || { print "ERROR: Failed to create log directory: $LOG_BASE_DIR"; exit 1; }

PROJECT_PATH=""
PROJECT_NAME=""
USER_BRANCH=""
LOG_FILE=""

# --------- Color Helper Functions ---------
color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red() { tput setaf 1; print "$1"; tput sgr0; }
color_cyan() { tput setaf 6; print "$1"; tput sgr0; }

# --------- Logging Function ---------
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
        *) print "$msg";;
    esac
}

# --------- Check for Git Repo ---------
check_git_repo() {
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        log_message ERROR "No .git directory found in $PROJECT_PATH"
        color_red "ERROR: Not a Git repository! Exiting."
        exit 1
    fi
}

# --------- Display Status ---------
print_git_status() {
    color_cyan "---------- GIT STATUS ----------"
    git status
    if [ $? -ne 0 ]; then
        log_message ERROR "git status failed"
        color_red "ERROR: Could not get Git status."
        exit 1
    fi
}

# --------- Select and Stage Changes ---------
select_changes_to_add() {
    typeset -a files_to_add
    cd "$PROJECT_PATH" || { log_message ERROR "Cannot cd to $PROJECT_PATH"; exit 1; }
    print_git_status

    # Use porcelain -z for NUL-separated output, robust with all file names
    git status --porcelain -z > .git_temp_status
    if [ ! -s .git_temp_status ]; then
        log_message INFO "No unstaged, modified, or untracked files found. Nothing to add."
        color_cyan "No changes to commit or push."
        rm -f .git_temp_status
        exit 0
    fi

    color_cyan "---------- FILES FOR ADD ----------"

    exec 3<.git_temp_status
    while IFS= read -r -u 3 -d '' entry; do
        status="${entry:0:2}"
        file="${entry:3}"
        [ -z "$file" ] && continue
        [ "$file" = ".git_temp_status" ] && continue  # Skip temp itself
        color_cyan "Staging? [$status] $file"
        print "Add this file to staging area? (yes/no) "
        read answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        if [ "$answer" = "yes" ]; then
            files_to_add=(${files_to_add[@]} "$file")
            log_message INFO "Selected: $file"
        else
            log_message INFO "Skipped: $file"
        fi
    done
    exec 3<&-

    rm -f .git_temp_status

    if [ ${#files_to_add[@]} -eq 0 ]; then
        log_message INFO "No files selected for staging/commit."
        color_cyan "No files were chosen for push."
        exit 0
    fi

    git add "${files_to_add[@]}"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Added/staged: ${files_to_add[*]}"
        color_green "Files staged successfully."
    else
        log_message ERROR "git add failed."
        color_red "ERROR: git add failed. Exiting."
        exit 1
    fi

    print_git_status
}


# --------- Commit with Message ---------
git_commit_changes() {
    print ""
    color_cyan "Please enter a commit message for this change:"
    read commit_msg
    [ -z "$commit_msg" ] && commit_msg="Routine update via script"

    git commit -m "$commit_msg"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Commit completed successfully."
        color_green "Commit recorded."
    else
        if git status | grep -q "nothing to commit"; then
            log_message INFO "Nothing was staged, nothing committed."
            color_cyan "Nothing committed. Exiting."
            exit 0
        fi
        log_message ERROR "git commit failed."
        color_red "ERROR: git commit failed. Exiting."
        exit 1
    fi
}

# --------- Branch Handling and Git Push ---------
git_push_changes() {
    branch_name="$1"

    color_cyan "---------- AVAILABLE BRANCHES ----------"
    git branch

    if [ -z "$branch_name" ]; then
        print ""
        color_cyan "No branch specified. Enter branch to push (leave blank for current):"
        read input_branch
        branch_name="$input_branch"
    fi
    if [ -z "$branch_name" ]; then
        branch_name=$(git symbolic-ref --short HEAD)
    fi

    git show-ref --verify --quiet "refs/heads/$branch_name"
    if [ $? -ne 0 ]; then
        log_message ERROR "Branch $branch_name does not exist."
        color_red "ERROR: Branch '$branch_name' does not exist."
        print "Use current branch $(git symbolic-ref --short HEAD) instead? (yes/no) "
        read answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        if [ "$answer" != "yes" ]; then
            color_cyan "Push cancelled by user."
            log_message INFO "Push cancelled by user. Nothing pushed."
            exit 0
        fi
        branch_name=$(git symbolic-ref --short HEAD)
    fi

    git push origin "$branch_name"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Push to origin/$branch_name successful."
        color_green "Push completed!"
    else
        log_message ERROR "git push failed. Check credentials, remote, or branch."
        color_red "ERROR: git push failed. See log for details."
        exit 1
    fi
}

# --------- Verify Commit is on GitHub via API ---------
verify_push_on_github() {
    repo_owner="karthikingithub"
    repo_name="project_setup_repo"
    branch_name="$1"
    github_token="$GITHUB_TOKEN"

    if [ -z "$github_token" ]; then
        color_red "ERROR: GITHUB_TOKEN is not set in environment. Skipping GitHub verify."
        log_message ERROR "GITHUB_TOKEN not set. Skipping GitHub verify."
        return
    fi

    print ""
    color_cyan "Verifying latest commit on GitHub..."

    response=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/repos/$repo_owner/$repo_name/branches/$branch_name")

    sha=$(echo "$response" | grep -o '"sha":"[^"]*' | head -1 | cut -d'"' -f4)
    author=$(echo "$response" | grep -o '"login":"[^"]*' | head -1 | cut -d'"' -f4)
    msg=$(echo "$response" | grep -o '"message":"[^"]*' | head -1 | cut -d'"' -f4)

    if [ -n "$sha" ]; then
        color_green "Push verified on GitHub!"
        color_cyan "Latest commit on $repo_name ($branch_name):"
        print "SHA: $sha"
        print "Author: $author"
        print "Message: $msg"
        print "URL: https://github.com/$repo_owner/$repo_name/commit/$sha"
        log_message SUCCESS "GitHub verification passed for commit $sha ($msg)"
    else
        color_red "Could not verify push on GitHub. Please check manually."
        log_message ERROR "GitHub commit verification failed."
    fi
}


# --------- Main Runner ---------
main() {
    if [ "$#" -lt 1 ]; then
        color_red "Usage: $0 <path_to_project/project_name> [branch]"
        exit 1
    fi

    PROJECT_PATH="$1"
    USER_BRANCH="$2"
    PROJECT_NAME=$(basename "$PROJECT_PATH")
    timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_BASE_DIR}/${SCRIPT_NAME}_${PROJECT_NAME}_${timestamp}.log"

    log_message INFO "Starting Git interactive check-in for $PROJECT_PATH"

    check_git_repo

    print_git_status

    select_changes_to_add

    git_commit_changes

    git_push_changes "$USER_BRANCH"

    verify_push_on_github "$USER_BRANCH"

    log_message SUCCESS "Git check-in and push cycle completed for $PROJECT_PATH"
}

main "$@"
