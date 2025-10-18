#!/bin/ksh

# Script Name: setup_project.sh
#
# Purpose:
#   This Korn shell script sets up a comprehensive project folder structure at a specified target path.
#   It:
#     - Creates multiple nested directories with descriptive README files.
#     - Creates key standard project files if missing.
#     - Sets up a Python virtual environment inside the project folder.
#     - Sets up a .gitignore file to ignore the virtual environment directory.
#     - Manages permissions for created directories.
#     - Logs all steps and prints color-coded messages for user feedback.
#   The script is designed to be safely rerun without overwriting existing files or directories.
#
# Usage:
#   ./setup_project.sh /target/path project_name
#
# Requirements:
#   - The config file $HOME/config.env must exist and set the LOG_BASE_DIR variable,
#     or the script will create logs under a hardcoded base directory.
#   - Python3 and venv module must be installed for virtual environment setup.
#
# Author:
#   Karthik KN
# Date:
#   10/18/2025

# Dynamically get the script name (without path and extension) for logs
SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${SCRIPT_NAME%.*}

PROJECT_PATH=""
LOG_BASE_DIR=""
LOG_FILE=""


# Global variables for project root path and name (set in main)
PROJECT_PATH=""
PROJECT_NAME=""

# Variable for current log file path (set dynamically in main)
LOG_FILE=""

# ---------------- Color Helper Functions ----------------
# Functions for printing colored messages to the terminal for clarity

color_green() {
  tput setaf 2
  print "$1"
  tput sgr0
}

color_red() {
  tput setaf 1
  print "$1"
  tput sgr0
}

color_cyan() {
  tput setaf 6
  print "$1"
  tput sgr0
}

# ---------------- Logging Function ----------------
# Logs a message with a timestamp to the logfile and prints color-coded console messages
#
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
    ERROR)   color_red "$msg" ;;
    INFO)    color_cyan "$msg" ;;
    *)       print "$msg" ;;
  esac
}

# ---------------- Directory Creation ----------------
# Creates a directory if it doesn't exist, sets permissions to 755,
# creates a README.txt describing the directory's purpose,
# and logs all actions and errors.
#
# Arguments:
#   $1 = Directory path to create/check
#   $2 = Content string to add to README.txt inside the directory

create_dir() {
  dir_path=$1
  readme_content=$2

  # Check if directory already exists
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

  # Create README.txt describing directory purpose if missing
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
# Creates essential standard project files with placeholder content if they do not exist,
# logging success or failure of each file creation

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
# Ensures 'venv/' directory is listed in .gitignore for excluding Python virtual environment

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
# Creates a Python virtual environment inside 'venv' folder if not already present

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
# Creates a comprehensive set of project directories with descriptions stored in README files

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

  # Loop to create each directory with description
  size=${#dirs[*]}
  i=0
  while (( i < size )); do
    create_dir "$PROJECT_PATH/${dirs[i]}" "${descs[i]}"
    (( i++ ))
  done
}

# ---------------- Load Environment Configuration ----------------
# Loads external environment variables including LOG_BASE_DIR from $HOME/config.env if exists

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

# ---------------- Main Function ----------------
# Validates arguments, sets global variables, creates log file,
# then performs full project setup including directories, files, venv, and gitignore

main() {
  if [ "$#" -ne 2 ]; then
    color_red "Usage: $0 /target/path project_name"
    exit 1
  fi

  target_path=$1
  project_name=$2

  # Set project root path and name
  PROJECT_PATH="${target_path%/}/$project_name"
  PROJECT_NAME="$project_name"

  load_config

  # Setup log directory and file
  LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}/"
  mkdir -p "$LOG_DIR" || { color_red "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }
  LOG_FILE="${LOG_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).log"

  log_message INFO "Starting setup for project: $PROJECT_NAME at $PROJECT_PATH"

  # Create root project directory
  create_dir "$PROJECT_PATH" "Root project directory: $PROJECT_NAME"

  # Create project subdirectories
  create_directories

  # Create essential key files
  create_key_files

  # Setup .gitignore for virtual environment exclusion
  setup_gitignore

  # Setup Python virtual environment
  setup_venv

  log_message SUCCESS "Full project setup completed successfully!"
  color_green "Setup successfully completed!"
}

# Execute main function with all command-line arguments
main "$@"
