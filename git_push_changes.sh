#!/bin/ksh

# Usage:
#   ./git_push_changes.sh /path/to/project/project_name [branch]
#
# Interactive git add/commit/push script.
# Reads GITHUB_TOKEN and REPO_OWNER from $HOME/config.env.
# Uses jq for GitHub verification JSON parsing.
# Logs debug and API responses to log file.
# Console shows minimal, user-friendly messages.

SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log/${SCRIPT_NAME}"
mkdir -p "$LOG_BASE_DIR" || { print "ERROR: Failed creating log directory: $LOG_BASE_DIR"; exit 1; }

PROJECT_PATH=""
PROJECT_NAME=""
USER_BRANCH=""
LOG_FILE=""
REPO_OWNER=""
GITHUB_TOKEN=""

load_config() {
    if [ -f "$HOME/config.env" ]; then
        . "$HOME/config.env"
        log_message INFO "Loaded config from $HOME/config.env"
    else
        color_red "WARNING: $HOME/config.env not found. Create it to set env vars."
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
        ERROR) color_red "$msg" ;;
        INFO) color_cyan "$msg" ;;
        *) print "$msg";;
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
    [ ! -s .git_temp_status ] && { log_message INFO "No changes to add"; color_cyan "No changes to commit or push."; rm -f .git_temp_status; exit 0; }

    color_cyan "---------- FILES FOR ADD ----------"

    exec 3<.git_temp_status
    while IFS= read -r -u 3 -d '' entry; do
        status=${entry:0:2}
        file=${entry:3}
        [ -z "$file" ] && continue
        [ "$file" = ".git_temp_status" ] && continue
        color_cyan "Staging? [$status] $file"
        print "Add this file? (yes/no) "
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

    [ ${#files_to_add[@]} -eq 0 ] && { log_message INFO "No files selected"; color_cyan "No files chosen for push."; exit 0; }

    git add "${files_to_add[@]}"
    [ $? -eq 0 ] && log_message SUCCESS "Added: ${files_to_add[*]}" || { log_message ERROR "git add failed"; color_red "git add failed"; exit 1; }

    print_git_status
}

git_commit_changes() {
    print ""; color_cyan "Enter commit message:"
    read commit_msg
    [ -z "$commit_msg" ] && commit_msg="Routine update"

    git commit -m "$commit_msg"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Commit successful."
        color_green "Commit recorded."
    else
        git status | grep -q "nothing to commit" && { log_message INFO "Nothing to commit"; color_cyan "Nothing committed. Exiting."; exit 0; }
        log_message ERROR "git commit failed."
        color_red "git commit failed. Exiting."
        exit 1
    fi
}

git_push_changes() {
    [ -z "$1" ] && {
        color_cyan "No branch specified. Enter branch (blank=current):"
        read branch_name
    } || branch_name="$1"

    [ -z "$branch_name" ] && branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)

    color_cyan "Available branches:"
    git -C "$PROJECT_PATH" branch

    git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$branch_name"
    if [ $? -ne 0 ]; then
        log_message ERROR "Branch $branch_name no exist."
        color_red "Branch $branch_name does not exist."
        color_cyan "Use current branch $(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)? (yes/no)"
        read yn
        yn=$(echo "$yn" | tr '[:upper:]' '[:lower:]')
        [ "$yn" != "yes" ] && { color_cyan "Push cancelled."; log_message INFO "Push cancelled."; exit 0; }
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    git -C "$PROJECT_PATH" push origin "$branch_name"
    [ $? -eq 0 ] && { log_message SUCCESS "Pushed origin/$branch_name"; color_green "Push completed!"; } || {
        log_message ERROR "git push failed"; color_red "git push failed, see log"; exit 1;
    }
}

print_commit_summary() {
    sha="$1"; author="$2"; msg="$3"; url="$4"
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
        color_red "jq not found, skipping verification."
        log_message ERROR "jq not found, skipping GitHub verification."
        return
    fi

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ]; then
        color_red "GITHUB_TOKEN or REPO_OWNER missing, skipping verification."
        log_message ERROR "GITHUB_TOKEN or REPO_OWNER missing, skipping verification."
        return
    fi

    color_cyan "Verifying latest commit on GitHub..."

    repo_name="$PROJECT_NAME"
    github_token="$GITHUB_TOKEN"
    repo_owner="$REPO_OWNER"
    branch_name="$1"

    response=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/repos/$repo_owner/$repo_name/branches/$branch_name")

    # Log API response ONLY
    log_message silentINFO "GitHub API response: $response"


    sha=$(echo "$response" | jq -r .commit.sha)
    msg=$(echo "$response" | jq -r .commit.commit.message)
    author=$(echo "$response" | jq -r .commit.commit.author.name)
    commit_url=$(echo "$response" | jq -r .commit.html_url)

    if [ "$sha" != "null" ]; then
        color_green "Push verified on GitHub!"
        print_commit_summary "$sha" "$author" "$msg" "$commit_url"
        log_message SUCCESS "GitHub verification succeeded for commit $sha ($msg)"
    else
        color_red "Could not verify push on GitHub. Check log."
        log_message ERROR "GitHub commit verification failed: $response"
    fi
}

show_recent_changes() {
    cd "$PROJECT_PATH" || { color_red "Cannot access $PROJECT_PATH"; return 1; }
    color_cyan "Enter number of recent commits to show (default 5):"
    read num_commits
    num_commits=${num_commits:-5}

    repo_name=$(basename "$PROJECT_PATH")

    # Print header
    printf "%-18s | %-10s | %-15s | %-10s | %-40s | %s\n" "Project" "Commit" "Author" "Date" "Message" "Files Changed"
    printf -- "---------------------------------------------------------------------------------------------------------------------------------------\n"

    # Get formatted log with files, using null byte as separator for files
    IFS=''
    git log -n "$num_commits" --pretty=format:"%H%x00%h%x00%an%x00%ad%x00%s" --date=short --name-only -z | \
    {
        read -r -d $'\0' full_sha
        while [ -n "$full_sha" ]; do
            read -r -d $'\0' short_sha
            read -r -d $'\0' author
            read -r -d $'\0' date
            read -r -d $'\0' message

            # Collect files for this commit until next commit SHA or EOF
            files=""
            while :; do
                read -r -d $'\0' line || break
                if [ "${#line}" -eq 40 ] && echo "$line" | grep -qE '^[0-9a-f]{40}$'; then
                    # Next commit SHA, break to next iteration
                    full_sha="$line"
                    break
                else
                    if [ -n "$line" ]; then
                        files="$files$line, "
                    fi
                fi
            done

            # Cleanup trailing comma and space on files
            files=$(echo "$files" | sed 's/, $//')

            printf "%-18s | %-10s | %-15s | %-10s | %-40s | %s\n" \
                "$repo_name" "$short_sha" "$author" "$date" "$message" "$files"

            # If EOF, no more commits
            [ -z "$full_sha" ] && break
        done
    }
}




main() {
    [ "$#" -lt 1 ] && { color_red "Usage: $0 <project_path> [branch]"; exit 1; }

    load_config

    PROJECT_PATH="$1"
    USER_BRANCH="$2"
    PROJECT_NAME=$(basename "$PROJECT_PATH")
    LOG_FILE="${LOG_BASE_DIR}/${SCRIPT_NAME}_${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    log_message INFO "Starting git check-in for $PROJECT_PATH"

    check_git_repo
    print_git_status
    select_changes_to_add
    git_commit_changes

    [ -z "$USER_BRANCH" ] && USER_BRANCH=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)

    git_push_changes "$USER_BRANCH"
    verify_push_on_github "$USER_BRANCH"

    log_message SUCCESS "Completed git check-in cycle for $PROJECT_PATH"
	
	color_cyan "Would you like to see recent commit summaries? (yes/no)"
	
	read ans
	if [ "$ans" = "yes" ]; then
		show_recent_changes
	fi

}

main "$@"

