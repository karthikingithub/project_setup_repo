# Project Setup & Cleanup Scripts

[![Shell Script](https://img.shields.io/badge/shell-ksh-blue.svg)](https://www.kornshell.com/)
[![Python 3](https://img.shields.io/badge/python-3.6%2B-blue.svg)](https://www.python.org/)
[![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen.svg)](https://github.com/karthikingithub/project_setup_repo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Issues](https://img.shields.io/github/issues/karthikingithub/project_setup_repo.svg)](https://github.com/karthikingithub/project_setup_repo/issues)
[![Stars](https://img.shields.io/github/stars/karthikingithub/project_setup_repo.svg?style=social)](https://github.com/karthikingithub/project_setup_repo/stargazers)

---

## Overview

This repository contains Korn shell (`ksh`) scripts designed for efficient setup, management, and cleanup of standardized project environments tailored for data engineering, AI workflows, or software projects. The key scripts automate common tasks with robust logging, colorized terminal output, and user-friendly interactive prompts.

### Key Features Across Scripts

- Modular creation of comprehensive project folder structures with detailed `README.txt` files for clarity.
- Initialization of essential root files including `README.md`, `requirements.txt`, `.gitignore`, `.env.example`, and `CHANGELOG.md`.
- Python virtual environment (`venv`) setup fully integrated and excluded in `.gitignore`.
- Interactive Git management: staging, committing, and pushing with GitHub API verification.
- Safe cleanup workflows with user confirmation and thorough logging.
- Safe to rerun any script without overwriting existing content accidentally.
- Timestamped log files maintained in configurable directories.

---

## Script Details

### `setup_project.sh`

- Creates a full project directory structure with folders such as `bin`, `src`, `tests`, `docs`, `data`, and others.
- Generates foundational files like `README.md`, `requirements.txt`, `.gitignore`, `.env.example`, and `CHANGELOG.md`.
- Sets up a Python virtual environment (`venv`) isolated from system Python.
- Prepares `README.txt` files in directories outlining their purpose.
- Idempotent: safe to rerun without overwriting existing setup.
- Logs all actions clearly with timestamps.

### `cleanup_project.sh`

- Interactively cleans project folders by removing all files and directories except `.git` and important config files.
- Safeguards uncommitted or staged Git changes, prompting before destructive cleanup.
- Removes generated log files older than a configurable retention period.
- Requires user confirmation at key stages for safety.

### `cleanup_old_logs.sh`

- Finds and deletes old script log files exceeding a user-specified age from all script log directories.
- Cleans up clutter from project and system logs to reclaim disk space.
- Requires confirmation before deletion.

### `git_checkout.sh`

- Enhanced Git branch management script.
- Accepts a GitHub URL as input; clones the repo into a subdirectory derived from the repo name within the supplied base path.
- Supports switching branches within existing local repos.
- Lists all local and remote branches before prompting user for input.
- If no branch is specified, asks to confirm fallback to `master` or `main`.
- Stashes uncommitted changes automatically before checkout and reapplies stash afterward.
- Logs detailed progress with timestamps and uses colorized output.
- Shows recent commit logs of the checked-out branch for quick context.

### `start_postgres_plsql.sh`

- Manages PostgreSQL server start and PLSQL session workflows.
- Reads database connection settings from environment config files.
- Starts PostgreSQL service if it isn't running.
- Executes provided PLSQL scripts or interacts with sessions as needed.
- Logs all significant actions and errors with timestamps.
- Facilitates seamless integration of PostgreSQL PLSQL work with project environments.

---

## Usage Examples

Make scripts executable first:


chmod +x setup_project.sh cleanup_project.sh cleanup_old_logs.sh git_checkout.sh git_push_changes.sh start_postgres_plsql.sh


- Setting up a new project:


./setup_project.sh /your/target/path your_project_name


- Cleaning up a project directory safely:

./cleanup_project.sh /your/target/path your_project_name


- Removing old logs (>30 days, configurable):


./cleanup_old_logs.sh


- Cloning a GitHub repo and switching branches via `git_checkout.sh`:



- Switching branches in an existing local git repo:


./git_checkout.sh /path/to/local/repo


- Starting PostgreSQL and running PLSQL scripts:


./start_postgres_plsql.sh /path/to/project/config.env


---

## Configuration

- All scripts rely on an environment config file located at `$HOME/config.env` (or custom project configs).
- Ensure this config exports necessary environment variables such as:


export LOG_BASE_DIR="/path/to/logs"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="your_user"
export DB_PASSWORD="your_password"
export REPO_OWNER="your_github_username"
export GITHUB_TOKEN="your_personal_access_token"


- Secure these configuration files appropriately.

---

## Logs

Scripts create timestamped logs in subdirectories of `$LOG_BASE_DIR` by script name and project. Example log file path:

$LOG_BASE_DIR/git_checkout/project_name_YYYYMMDD_HHMMSS.log


---

## Contribution & Support

Contributions, bug reports, and pull requests are welcome.

---





Maintained by Karthik K.N

---

Thank you for using these scripts! Customize as necessary for your workflows and organizational requirements.
