#!/bin/ksh

# Usage:
#   ./setup_project.sh /target/path project_name
#
# This Korn shell script creates a comprehensive project folder structure,
# initializes key files, sets up a Python virtual environment,
# manages permissions, logs all steps, and prints colored messages.
# It is designed to be safely rerun without overwriting existing files/directories.

# Dynamically get the script name (basename without path and extension)
SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

# Base directory where logs will be stored for this script
LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log/${SCRIPT_NAME}"

# Create log dir if missing, exit if fail
mkdir -p "$LOG_BASE_DIR" || { print "ERROR: Failed to create log directory: $LOG_BASE_DIR"; exit 1; }

# Global variables for project root path and name, to be set in main()
PROJECT_PATH=""
PROJECT_NAME=""

# Variable for current log file path, set dynamically in main()
LOG_FILE=""

# ---------------- Color Helper Functions ----------------
# These functions print colored messages using tput for compatibility

# Print in green (success messages)
color_green() {
    tput setaf 2
    print "$1"
    tput sgr0
}

# Print in red (error messages)
color_red() {
    tput setaf 1
    print "$1"
    tput sgr0
}

# Print in cyan (informational messages)
color_cyan() {
    tput setaf 6
    print "$1"
    tput sgr0
}

# ---------------- Logging Function ----------------
# Logs a message with timestamp to logfile, prints colored message to console.
# Arguments:
#   $1 = Log level (SUCCESS, ERROR, INFO)
#   $2 = The message string
log_message() {
    level=$1
    shift
    msg=$*

    # Timestamp for log entries
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Write message to log file with timestamp and level
    print "$timestamp [$level] $msg" >> "$LOG_FILE"

    # Print message on console with color based on log level
    case "$level" in
        SUCCESS) color_green "$msg" ;;
        ERROR) color_red "$msg" ;;
        INFO) color_cyan "$msg" ;;
        *) print "$msg";;
    esac
}

# ---------------- Directory Creation ----------------
# Creates a directory if it doesn't exist, sets permissions to 755,
# creates a README.txt describing the directory's purpose,
# and logs all actions and errors.
# Arguments:
#   $1 = Directory path to create/check
#   $2 = Content string to add to README.txt inside the directory
create_dir() {
    dir_path=$1
    readme_content=$2

    # Check for directory existence
    if [ -d "$dir_path" ]; then
        log_message INFO "Directory already exists: $dir_path"
    else
        # Create directory and log success or failure
        mkdir -p "$dir_path"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Created directory: $dir_path"
        else
            log_message ERROR "Failed to create directory: $dir_path"
            exit 1
        fi
    fi

    # Set directory permissions to 755 and verify
    chmod 755 "$dir_path"
    if [ $? -eq 0 ]; then
        log_message INFO "Set permissions 755 on directory: $dir_path"
    else
        log_message ERROR "Failed to set permissions 755 on directory: $dir_path"
        exit 1
    fi

    # Create README.txt describing directory purpose, if missing
    readme_file="${dir_path}/README.txt"
    if [ ! -f "$readme_file" ]; then
        print "$readme_content" > "$readme_file"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Created README.txt in $dir_path"
        else
            log_message ERROR "Failed to create README.txt in $dir_path"
            exit 1
        fi
    else
        log_message INFO "README.txt already exists in $dir_path"
    fi
}

# ---------------- Key Project File Creation ----------------
# Creates essential project files with placeholder content if they don't exist,
# logs success/failure for each.
create_key_files() {
    files="requirements.txt README.md .gitignore .env.example CHANGELOG.md"
    for file in $files; do
        full_path="$PROJECT_PATH/$file"
        if [ -f "$full_path" ]; then
            log_message INFO "File exists: $full_path"
        else
            print "# Placeholder" > "$full_path"
            if [ $? -eq 0 ]; then
                log_message SUCCESS "Created $full_path"
            else
                log_message ERROR "Failed to create $full_path"
                exit 1
            fi
        fi
    done
}

# ---------------- .gitignore Setup ----------------
# Ensures 'venv/' is listed in .gitignore for excluding python virtual env
setup_gitignore() {
    gitignore_file="$PROJECT_PATH/.gitignore"
    if ! grep -q "^venv/$" "$gitignore_file" 2>/dev/null; then
        print "venv/" >> "$gitignore_file"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Added venv/ to .gitignore"
        else
            log_message ERROR "Failed to update .gitignore"
            exit 1
        fi
    else
        log_message INFO "venv/ already listed in .gitignore"
    fi
}

# ---------------- Python Virtual Environment Setup ----------------
# Creates Python virtual environment inside 'venv' folder if not found
setup_venv() {
    venv_path="$PROJECT_PATH/venv"
    if [ -d "$venv_path" ]; then
        log_message INFO "Virtual environment already exists."
    else
        python3 -m venv "$venv_path"
        if [ $? -eq 0 ]; then
            log_message SUCCESS "Created virtual environment at $venv_path"
        else
            log_message ERROR "Failed to create virtual environment"
            exit 1
        fi
    fi
}

# ---------------- Create Project Directories ----------------
# Uses two parallel ksh arrays for directory paths and their README contents.
# Iterates and creates each directory with its descriptive README.txt.
create_directories() {
    set -A dirs \
        "airflow/dags" "airflow/plugins" "airflow/config" \
        "db/migrations" "db/seed_data" "db/functions" \
        "src/models" "src/queries" "src/services" "src/main_app_code" "src/utilities" \
        "config" \
        "scripts/scheduling" "scripts/setup" \
        "data/raw" "data/external" "data/interim" "data/processed" "data/input" "data/output" \
        "error" "logs" "tests" "docs" \
        "prompt_templates" "agents" "protocols" "tools" "memory" \
        "workflows" "orchestrators" "models" "experiments" "notebooks" "pipeline" \
        "references" "deployment" "assets" "saved_objects"

    set -A descs \
        "Airflow DAG workflow definitions (Python files)." \
        "Custom Airflow operators, sensors, and hooks." \
        "Airflow configuration files like airflow.cfg overrides." \
        "Database schema migration scripts." \
        "Initial or test seed data for the database." \
        "SQL stored procedures and user-defined functions." \
        "Data models or ORM definitions." \
        "Complex SQL or data queries." \
        "Business logic and API service layers." \
        "Main application executable code or modules." \
        "Helper functions, utilities, and reusable code." \
        "Configuration files for the app and database." \
        "Cron jobs, autolysis, and other scheduler scripts outside Airflow." \
        "Environment setup, bootstrap, and dependency installation scripts." \
        "Immutable source data dumps." \
        "Third-party or external datasets." \
        "Temporary or intermediate datasets during processing." \
        "Cleaned and processed data ready for use." \
        "Input files for processing." \
        "Output files, reports, and processed results." \
        "Error logs and exception capture files." \
        "Application, pipeline, and batch run logs." \
        "Unit, integration, and performance tests." \
        "Project documentation, architecture diagrams, and guides." \
        "Reusable prompt templates for AI workflows." \
        "Modular agent definitions (planning, execution, monitoring)." \
        "Communication protocols for agent messaging." \
        "Wrappers for APIs, databases, search, and summarization tools." \
        "Vectorized or episodic memory modules for agents." \
        "Definitions of agent and data workflows/pipelines." \
        "Orchestration layers like LangGraph or CrewAI integration." \
        "Saved ML and AI model artifacts and checkpoints." \
        "Experiment metadata, configuration, and result tracking." \
        "Jupyter notebooks for exploration and prototyping." \
        "Pipeline orchestration and ETL/ML workflow definitions." \
        "Research papers, specifications, and benchmark documents." \
        "CI/CD, Dockerfiles, Kubernetes manifests, deployment automation." \
        "Supporting visuals, architecture diagrams, and presentations." \
        "Serialized data and intermediate objects storage."

    # Get number of directories to create
    size=${#dirs[*]}

    i=0
    while (( i < size )); do
        create_dir "$PROJECT_PATH/${dirs[i]}" "${descs[i]}"
        (( i++ ))
    done
}

# ---------------- Main ----------------
# Entry point, validates args, sets global paths and log file, then runs setup steps.
main() {
    if [ "$#" -ne 2 ]; then
        color_red "Usage: $0 <target_path> <project_name>"
        exit 1
    fi

    target_path=$1
    project_name=$2
    PROJECT_PATH="${target_path%/}/$project_name"
    PROJECT_NAME="$project_name"

    # Construct log file path including script name, project name, and timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_BASE_DIR}/${SCRIPT_NAME}_${PROJECT_NAME}_${timestamp}.log"

    log_message INFO "Starting setup for project: $PROJECT_NAME at $PROJECT_PATH"

    # Create root project directory
    create_dir "$PROJECT_PATH" "Root project directory: $PROJECT_NAME"

    # Create project subdirectories
    create_directories

    # Create key files in root
    create_key_files

    # Setup .gitignore contents
    setup_gitignore

    # Setup python virtual environment
    setup_venv

    log_message SUCCESS "Full project setup completed successfully!"
    color_green "Setup successfully completed!"
}

# Execute main function passing all positional arguments
main "$@"
