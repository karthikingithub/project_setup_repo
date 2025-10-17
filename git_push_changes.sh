#!/bin/ksh

# Usage:
#   ./git_push_changes.sh /path/to/project/project_name [branch]
#
# Interactive git add/commit/push script.
# Reads GITHUB_TOKEN and REPO_OWNER from $HOME/config.env.
# Uses 'jq' for JSON parsing.
# Prints pretty summary table for commits.
# Robust logging and error handling.

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log/${SCRIPT_NAME}"
mkdir -p "$LOG_BASE_DIR" || { print "ERROR: Failed to create log directory: $LOG_BASE_DIR"; exit 1; }

PROJECT_PATH=""
PROJECT_NAME=""
USER_BRANCH=""
LOG_FILE=""
REPO_OWNER=""

load_config() {
    if [ -f "$HOME/config.env" ]; then
        . "$HOME/config.env"
        log_message INFO "Loaded config from $HOME/config.env"
    else
        color_red "WARNING: $HOME/config.env not found. Please create it."
        log_message ERROR "$HOME/config.env not found."
    fi

    if [ -z "$GITHUB_TOKEN" ]; then
        color_red "WARNING: GITHUB_TOKEN is not set."
        log_message ERROR "GITHUB_TOKEN not set."
    fi
    if [ -z "$REPO_OWNER" ]; then
        color_red "WARNING: REPO_OWNER is not set."
        log_message ERROR "REPO_OWNER not set."
    fi
}

color_green() { tput setaf 2; print "$1"; tput sgr0; }
color_red() { tput setaf 1; print "$1"; tput sgr0; }
color_cyan() { tput setaf 6; print "$1"; tput sgr0; }

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

check_git_repo() {
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        log_message ERROR "No .git directory found in $PROJECT_PATH"
        color_red "ERROR: Not a Git repository! Exiting."
        exit 1
    fi
}

print_git_status() {
    color_cyan "---------- GIT STATUS ----------"
    git status
    if [ $? -ne 0 ]; then
        log_message ERROR "git status failed"
        color_red "ERROR: Could not get Git status."
        exit 1
    fi
}

select_changes_to_add() {
    typeset -a files_to_add
    cd "$PROJECT_PATH" || { log_message ERROR "Cannot cd to $PROJECT_PATH"; exit 1; }
    print_git_status

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
        [ "$file" = ".git_temp_status" ] && continue
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

git_push_changes() {
    if [ -z "$1" ]; then
        print ""
        color_cyan "No branch specified. Enter branch to push (leave blank for current):"
        read branch_name
    else
        branch_name="$1"
    fi

    if [ -z "$branch_name" ]; then
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    color_cyan "---------- AVAILABLE BRANCHES ----------"
    git -C "$PROJECT_PATH" branch

    git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$branch_name"
    if [ $? -ne 0 ]; then
        log_message ERROR "Branch $branch_name does not exist."
        color_red "ERROR: Branch '$branch_name' does not exist."
        print "Use current branch $(git -C "$PROJECT_PATH" symbolic-ref --short HEAD) instead? (yes/no) "
        read answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        if [ "$answer" != "yes" ]; then
            color_cyan "Push cancelled by user."
            log_message INFO "Push cancelled by user. Nothing pushed."
            exit 0
        fi
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    git -C "$PROJECT_PATH" push origin "$branch_name"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Push to origin/$branch_name successful."
        color_green "Push completed!"
    else
        log_message ERROR "git push failed. Check credentials, remote, or branch."
        color_red "ERROR: git push failed. See log for details."
        exit 1
    fi
}

print_commit_summary() {
    sha="$1"
    author="$2"
    msg="$3"
    url="$4"

    # Pretty print a table (simple)
    print ""
    color_cyan "------ Push Verification Summary ------"
    printf "%-10s : %s\n" "Commit SHA" "$sha"
    printf "%-10s : %s\n" "Author" "$author"
    printf "%-10s : %s\n" "Message" "$msg"
    printf "%-10s : %s\n" "URL" "$url"
    print "---------------------------------------"
    print ""
}

verify_push_on_github() {
    if ! command -v jq >/dev/null 2>&1; then
        color_red "jq is not installed. Skipping GitHub push verification."
        log_message ERROR "jq not installed, skipping GitHub verification."
        return
    fi

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ]; then
        color_red "ERROR: GITHUB_TOKEN or REPO_OWNER is not set. Skipping GitHub verify."
        log_message ERROR "GITHUB_TOKEN or REPO_OWNER not set. Skipping GitHub verify."
        return
    fi

    print ""
    color_cyan "Verifying latest commit on GitHub..."

    repo_name="$PROJECT_NAME"
    github_token="$GITHUB_TOKEN"
    repo_owner="$REPO_OWNER"
    branch_name="$1"

    response=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/repos/$repo_owner/$repo_name/branches/$branch_name")

    log_message INFO "GitHub API response: $response"

    sha=$(echo "$response" | jq -r .commit.sha)
    msg=$(echo "$response" | jq -r .commit.commit.message)
    author=$(echo "$response" | jq -r .commit.commit.author.name)
    commit_url=$(echo "$response" | jq -r .commit.html_url)

    if [ "$sha" != "null" ]; then
        color_green "Push verified on GitHub!"
        print_commit_summary "$sha" "$author" "$msg" "$commit_url"
        log_message SUCCESS "GitHub verification passed for commit $sha ($msg)"
    else
        color_red "Could not verify push on GitHub. Please check manually."
        log_message ERROR "GitHub commit verification failed. Response: $response"
    fi
}

main() {
    if [ "$#" -lt 1 ]; then
        color_red "Usage: $0 <path_to_project/project_name> [branch]"
        exit 1
    fi

    load_config

    PROJECT_PATH="$1"
    USER_BRANCH="$2"
    PROJECT_NAME=$(basename "$PROJECT_PATH")
    LOG_FILE="${LOG_BASE_DIR}/${SCRIPT_NAME}_${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting Git interactive check-in for $PROJECT_PATH"

    check_git_repo

    print_git_status

    select_changes_to_add

    git_commit_changes

    if [ -z "$USER_BRANCH" ]; then
        USER_BRANCH=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    git_push_changes "$USER_BRANCH"

    verify_push_on_github "$USER_BRANCH"

    log_message SUCCESS "Git check-in and push cycle completed for $PROJECT_PATH"
}

main "$@"
