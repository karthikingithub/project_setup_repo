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

- Creates a full project folder structure including subdirectories for `src`, `data`, `scripts`, `config`, `tests`, `docs`, `agents`, `workflows`, and many others.
- Populates each directory with helpful `README.txt` describing its purpose.
- Sets up basic key files at the project root if missing.
- Initializes a Python virtual environment (`venv`) within the project and configures `.gitignore` accordingly.
- Handles folder permissions and logs all setup actions.

---

### `cleanup_project.sh`

- Safely deletes an entire project directory tree after explicit user confirmation.
- Checks for directory existence before deletion.
- Logs every step including user responses and deletion outcomes.
- Prevents accidental removal by requiring a typed confirmation (`yes`).

---

### `cleanup_old_logs.sh`

- Recursively deletes log files older than 60 days under the configured centralized log directory.
- Identifies empty directories inactive for 60 or more days and prompts user whether to delete them.
- Logs every deletion attempt and user decision for audit purposes.
- Requires `LOG_BASE_DIR` environment variable configured via `$HOME/config.env`.

---

### `git_checkout.sh`

- Facilitates switching Git branches safely within a project repository.
- Validates repository status and existence of branches.
- Lists available local and remote branches for user reference.
- Handles stashing and reapplying uncommitted changes during branch switches.
- Falls back to common default branches like `main` or `master` if the requested branch is unavailable.
- Provides recent commit logs of checked out branch for quick context.

---

### `git_push_changes.sh`

- Streamlines the process of staging, committing, and pushing Git changes interactively.
- Prompts users per changed file for staging selection.
- Allows commit message input and optional author override.
- Performs safe push operations to the remote repository.
- Verifies pushed commits via GitHub API using configured personal access tokens.
- Generates changelogs automatically after successful pushes.
- Optionally shows recent commit summaries in a formatted table for quick review.

---

## Usage

Make scripts executable first:

chmod +x setup_project.sh cleanup_project.sh cleanup_old_logs.sh git_checkout.sh git_push_changes.sh


Example commands:

- Set up a new project:


./setup_project.sh /your/target/path your_project_name


- Clean up a project directory:

./cleanup_project.sh /your/target/path your_project_name


- Clean old logs:

./cleanup_old_logs.sh


- Switch Git branches safely:

./git_checkout.sh /absolute/path/to/your/project


- Commit and push changes with interactive prompts:

ksh git_push_changes.sh /absolute/path/to/your/project


---

## Configuration

Ensure `$HOME/config.env` is set up with the following environment variables:



export LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log"
export REPO_OWNER="your_github_username"
export GITHUB_TOKEN="your_personal_access_token"


---

## Logging

All scripts create timestamped logs stored at:


$LOG_BASE_DIR/<script_name>/<project_name>_<timestamp>.log


Typical log files include:

- `setup_project_<project_name>_YYYYMMDD_HHMMSS.log`
- `cleanup_project_<project_name>_YYYYMMDD_HHMMSS.log`
- `cleanup_old_logs_YYYYMMDD_HHMMSS.log`
- `git_checkout_<project_name>_YYYYMMDD_HHMMSS.log`
- `git_push_changes_<project_name>_YYYYMMDD_HHMMSS.log`

---

## Contribution

Please open issues or submit pull requests for improvements, bug fixes, or new features. Contributions and feedback are welcome.

---

## Maintainer

Karthik KN

---

Thank you for using these scripts! Feel free to customize them for your organizational workflows and project requirements.



