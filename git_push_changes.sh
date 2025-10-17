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
GIT_AUTHOR_NAME=""
GIT_AUTHOR_EMAIL=""

load_config() {
    if [ ! -f "$HOME/config.env" ]; then
        color_red "ERROR: Config file $HOME/config.env missing. Cannot proceed."
        exit 1
    fi

    . "$HOME/config.env"

    if [ -z "$LOG_BASE_DIR" ]; then
        color_red "ERROR: LOG_BASE_DIR not set in config."
        exit 1
    fi
    if [ -z "$REPO_OWNER" ]; then
        color_red "ERROR: REPO_OWNER not set in config."
        exit 1
    fi
    if [ -z "$GITHUB_TOKEN" ]; then
        color_red "ERROR: GITHUB_TOKEN not set in config."
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
    [ "$silent" -eq 1 ] && return
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
    cd "$PROJECT_PATH" || { log_message ERROR "Cannot cd $PROJECT_PATH"; return 1; }

    print_git_status

    # Show diff preview of unstaged changes
    color_cyan "Preview of Uncommitted Changes (git diff --stat):"
    git diff --stat

    git status --porcelain -z > .git_temp_status
    if [ ! -s .git_temp_status ]; then
        log_message INFO "No unstaged or untracked changes"
        color_cyan "No changes to commit or push."
        rm -f .git_temp_status
        return 1
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
        return 1
    fi

    git add "${files_to_add[@]}"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Added files: ${files_to_add[*]}"
        color_green "Files staged successfully."
    else
        log_message ERROR "git add failed."
        color_red "git add failed. Exiting."
        return 2
    fi

    print_git_status

    # Show diff preview of staged changes
    color_cyan "Review STAGED CHANGES to be committed (git diff --cached --stat):"
    git diff --cached --stat

    return 0
}

git_commit_changes() {
    color_cyan "Enter commit message:"
    read commit_msg
    [ -z "$commit_msg" ] && commit_msg="Routine update"

    if [ -n "$GIT_AUTHOR_NAME" ] && [ -n "$GIT_AUTHOR_EMAIL" ]; then
        git -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" commit -m "$commit_msg"
    else
        git commit -m "$commit_msg"
    fi
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Commit successful."
        color_green "Commit recorded."
        return 0
    else
        git status | grep -q "nothing to commit" && {
            log_message INFO "Nothing to commit."
            color_cyan "Nothing committed."
            return 1
        }
        log_message ERROR "git commit failed."
        color_red "git commit failed."
        return 2
    fi
}

git_push_changes() {
    if [ -z "$1" ]; then
        color_cyan "Enter branch to push (leave blank for current):"
        read branch_name
    else
        branch_name="$1"
    fi

    [ -z "$branch_name" ] && branch_name=$(git -C "$PROJECT_PATH" symbolic_ref --short HEAD)

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
            return 1
        fi
        branch_name=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
    fi

    git -C "$PROJECT_PATH" push origin "$branch_name"
    if [ $? -eq 0 ]; then
        log_message SUCCESS "Pushed origin/$branch_name"
        color_green "Push completed!"
        return 0
    else
        log_message ERROR "git push failed."
        color_red "git push failed, see log."
        return 2
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
        return 1
    fi

    if [ -z "$GITHUB_TOKEN" ] || [ -z "$REPO_OWNER" ]; then
        color_red "GITHUB_TOKEN or REPO_OWNER missing, skipping verification."
        log_message ERROR "Missing GITHUB_TOKEN or REPO_OWNER."
        return 1
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
        return 0
    else
        color_red "Could not verify push on GitHub. Please check the log."
        log_message ERROR "GitHub verification failed: $response"
        return 1
    fi
}

generate_changelog() {
    cd "$PROJECT_PATH" || return
    color_cyan "Generating change log for latest commits."
    num_entries=10
    changelog_file="${LOG_DIR}/CHANGELOG_$(date +%Y%m%d_%H%M%S).txt"
    git log -n "$num_entries" --pretty=format:"%h | %an | %ad | %s" --date=short > "$changelog_file"
    color_green "Changelog written to $changelog_file"
}

show_recent_changes() {
    cd "$PROJECT_PATH" || { color_red "Cannot access $PROJECT_PATH"; return 1; }
    color_cyan "How many recent commits do you want to see? (default 5):"
    read num_commits
    num_commits=${num_commits:-5}
    repo_name=$(basename "$PROJECT_PATH")
    w_project=18; w_commit=8; w_author=14; w_date=10; w_message=34; w_files=30
    printf "%-${w_project}s | %-${w_commit}s | %-${w_author}s | %-${w_date}s | %-${w_message}s | %-${w_files}s\n" \
      "Project" "Commit" "Author" "Date" "Message" "Files Changed"
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
        [ "${#message}" -gt $w_message ] && t_message="$t_message…"
        t_files=$(echo "$files" | cut -c1-$w_files)
        [ "${#files}" -gt $w_files ] && t_files="$t_files…"
        printf "%-${w_project}s | %-${w_commit}s | %-${w_author}s | %-${w_date}s | %-${w_message}s | %-${w_files}s\n" \
          "$repo_name" "$short_sha" "$author" "$date" "$t_message" "$t_files"
    done
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
	SCRIPT_NAME=$(basename $0)
	SCRIPT_NAME=${SCRIPT_NAME%.*}
	
	LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}/"
	mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
	LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

    color_cyan "Override git author? (leave blank for default, or format 'Name <email>'):"
    read custom_author
    if [ -n "$custom_author" ]; then
        export GIT_AUTHOR_NAME="$(echo $custom_author | sed 's/ *<.*//')"
        export GIT_AUTHOR_EMAIL="$(echo $custom_author | sed -n 's/.*<\(.*\)>/\1/p')"
        color_green "Author set for commit: $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"
    fi

    log_message INFO "Starting git check-in for $PROJECT_PATH"

    check_git_repo

    sel_status=1
    select_changes_to_add
    sel_status=$?

    commit_status=1
    if [ $sel_status -eq 0 ]; then
        git_commit_changes
        commit_status=$?
        if [ $commit_status -eq 0 ]; then
            print_git_status
            [ -z "$USER_BRANCH" ] && USER_BRANCH=$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD)
            git_push_changes "$USER_BRANCH"
            verify_push_on_github "$USER_BRANCH"
            generate_changelog
        fi
    fi

    color_cyan "Would you like to see recent commit summaries? (yes/no)"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [ "$answer" = "yes" ]; then
        show_recent_changes
    fi

    log_message SUCCESS "Completed git check-in cycle for $PROJECT_PATH"
}

main "$@"
