#!/bin/ksh

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

PROJECT_PATH=""
PROJECT_NAME=""
USER_BRANCH=""
LOG_FILE=""
LOG_BASE_DIR=""
REPO_OWNER=""
GITHUB_TOKEN=""

load_config() {
    if [ ! -f "$HOME/config.env" ]; then
        color_red "ERROR: Config file $HOME/config.env missing. Cannot proceed."
        exit 1
    fi

    . "$HOME/config.env"

    if [ -z "$LOG_BASE_DIR" ]; then
        color_red "ERROR: LOG_BASE_DIR not set in config : $HOME/config.env"
        exit 1
    fi
    if [ -z "$REPO_OWNER" ]; then
        color_red "ERROR: REPO_OWNER not set in config.: $HOME/config.env"
        exit 1
    fi
    if [ -z "$GITHUB_TOKEN" ]; then
        color_red "ERROR: GITHUB_TOKEN not set in config.: $HOME/config.env"
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
    silent=0
    if [[ "$level" == silent* ]]; then
        level=${level#silent}
        silent=1
    fi
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    print "$timestamp [$level] $msg" >> "$LOG_FILE"
    if [ "$silent" -eq 1 ]; then
        return
    fi
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

print_git_status() {
    color_cyan "---------- GIT STATUS ----------"
    git status
    [ $? -ne 0 ] && { log_message ERROR "git status failed"; color_red "ERROR: git status failed"; exit 1; }
}

select_changes_to_add() {
    typeset -a files_to_add
    cd "$PROJECT_PATH" || { log_message ERROR "Cannot cd $PROJECT_PATH"; exit 1; }
    print_git_status

    git status --porcelain -z > .git_temp_status
    if [ ! -s .git_temp_status ]; then
        log_message INFO "No unstaged or untracked changes"
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
        color_cyan "Stage? [$status] $file"
        print "Add this file? (yes/no): "
        read ans
        ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
        if [ "$ans" = "yes" ]; then
            files_to_add=(${files_to_add[@]} "$file")
            log_message INFO "Selected: $file"
        else
            log_message INFO "Skipped: $file"
        fi
    done
    exec 3<&-

    rm -f .git_temp_status

    if [ ${#files_to_add[@]} -eq 0 ]; then
        log_message INFO "No files selected."
        color_cyan "No files chosen for commit."
        exit 0
    fi

    git add "${files_to_add[@]}"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Added files: ${files_to_add[*]}"
        color_green "Files staged successfully."
    else
        log_message ERROR "git add failed."
        color_red "git add failed. Exiting."
        exit 1
    fi

    print_git_status
}

git_commit_changes() {
    color_cyan "Enter commit message:"
    read commit_msg
    [ -z "$commit_msg" ] && commit_msg="Routine update"

    git commit -m "$commit_msg"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Commit successful."
        color_green "Commit recorded."
    else
        git status | grep -q "nothing to commit" && {
            log_message INFO "Nothing to commit."
            color_cyan "Nothing committed. Exiting."
            exit 0
        }
        log_message ERROR "git commit failed."
        color_red "git commit failed. Exiting."
        exit 1
    fi
}

git_push_changes() {
    if [ -z "$1" ]; then
        color_cyan "Enter branch to push (leave blank for current):"
        read branch_name
    else
        branch_name="$1"
    fi

    [ -z "$branch_name" ] && branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)

    color_cyan "Available branches:"
    git -C "$PROJECT_PATH" branch

    git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$branch_name"
    if [ $? -ne 0 ]; then
        log_message ERROR "Branch $branch_name does not exist."
        color_red "ERROR: Branch '$branch_name' does not exist."
        color_cyan "Use current branch $(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)? (yes/no)"
        read yn
        yn=$(echo "$yn" | tr '[:upper:]' '[:lower:]')
        if [ "$yn" != "yes" ]; then
            color_cyan "Push cancelled."
            log_message INFO "Push cancelled by user."
            exit 0
        fi
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    git -C "$PROJECT_PATH" push origin "$branch_name"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Pushed origin/$branch_name"
        color_green "Push completed!"
    else
        log_message ERROR "git push failed."
        color_red "git push failed, see log."
        exit 1
    fi
}

print_commit_summary() {
    sha="$1"; author="$2"; msg="$3"; url="$4"

    color_cyan "------ Push Verification Summary ------"
    printf "%-12s : %s\n" "Commit SHA" "$sha"
    printf "%-12s : %s\n" "Author" "$author"
    printf "%-12s : %s\n" "Message" "$msg"
    printf "%-12s : %s\n" "URL" "$url"
    echo "---------------------------------------"
}

verify_push_on_github() {
    if ! command -v jq >/dev/null 2>&1; then
        color_red "jq not found, skipping verification."
        log_message ERROR "jq not found."
        return
    fi

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ]; then
        color_red "GITHUB_TOKEN or REPO_OWNER missing, skipping verification."
        log_message ERROR "Missing GITHUB_TOKEN or REPO_OWNER."
        return
    fi

    color_cyan "Verifying latest commit on GitHub..."

    repo_name="$PROJECT_NAME"
    github_token="$GITHUB_TOKEN"
    repo_owner="$REPO_OWNER"
    branch_name="$1"

    response=$(curl -s -H "Authorization: token $github_token" \
        "https://api.github.com/repos/$repo_owner/$repo_name/branches/$branch_name")

    # Log API response silently (no console print)
    log_message silentINFO "GitHub API response: $response"

    sha=$(echo "$response" | jq -r .commit.sha)
    msg=$(echo "$response" | jq -r .commit.commit.message)
    author=$(echo "$response" | jq -r .commit.commit.author.name)
    commit_url=$(echo "$response" | jq -r .commit.html_url)

    if [ "$sha" != "null" ]; then
        color_green "Push verified on GitHub!"
        print_commit_summary "$sha" "$author" "$msg" "$commit_url"
        log_message SUCCESS "GitHub verification succeeded for commit $sha"
    else
        color_red "Could not verify push on GitHub. Please check the log."
        log_message ERROR "GitHub verification failed: $response"
    fi
}

show_recent_changes() {
    cd "$PROJECT_PATH" || { color_red "Cannot access $PROJECT_PATH"; return 1; }
    color_cyan "How many recent commits do you want to see? (default 5):"
    read num_commits
    num_commits=${num_commits:-5}

    repo_name=$(basename "$PROJECT_PATH")

    printf "%-18s | %-10s | %-15s | %-10s | %-40s | %s\n" "Project" "Commit" "Author" "Date" "Message" "Files Changed"
    printf -- "-----------------------------------------------------------------------------------------------------------------------------------\n"

    git log -n "$num_commits" --pretty=format:"%H%x00%h%x00%an%x00%ad%x00%s" --date=short --name-only -z | {
        while true; do
            read -r -d $'\0' full_sha || break
            read -r -d $'\0' short_sha || break
            read -r -d $'\0' author || break
            read -r -d $'\0' date || break
            read -r -d $'\0' message || break

            files=""
            while IFS= read -r -d $'\0' file; do
                if [ ${#file} -eq 40 ] && echo "$file" | grep -qE '^[0-9a-f]{40}$'; then
                    next_commit_sha="$file"
                    break
                fi
                files="${files}${file}, "
            done
            files=${files%, }

            printf "%-18s | %-10s | %-15s | %-10s | %-40s | %s\n" "$repo_name" "$short_sha" "$author" "$date" "$message" "$files"

            if [ -n "$next_commit_sha" ]; then
                full_sha="$next_commit_sha"
                unset next_commit_sha
            else
                break
            fi
        done
    }
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

    LOG_DIR="${LOG_BASE_DIR}/${PROJECT_NAME}"
    mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
    LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting git check-in for $PROJECT_PATH"

    check_git_repo
    print_git_status
    select_changes_to_add
    git_commit_changes

    [ -z "$USER_BRANCH" ] && USER_BRANCH=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)

    git_push_changes "$USER_BRANCH"
    verify_push_on_github "$USER_BRANCH"

    color_cyan "Would you like to see recent commit summaries? (yes/no)"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [ "$answer" = "yes" ]; then
        show_recent_changes
    fi

    log_message SUCCESS "Completed git check-in cycle for $PROJECT_PATH"
}

main "$@"
