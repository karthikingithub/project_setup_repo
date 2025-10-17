[![Shell Script](https://img.shields.io/badge(https://www.kornshell.comhttps://img.shields.io/badge
[![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen(https://github.com/karthikingithub/project_setup_repohttps://img.shields.io/badge(https://opensource.org/licenseshttps://img.shields.io/github/issues/karthikingithub/project(https://github.com/karthikingithub/project_setup_repohttps://img.shields.io/github/stars/karthikingithub/project_setup_repo.svg?style=social(https://github.com/karthikingithub/project_setup_repo

This repository contains Korn shell (ksh) scripts designed for efficient setup and cleanup of standardized project environments. Suitable for data engineering, AI workflows, or software projects, it includes:

Modular creation of comprehensive project folder structures with helpful README.txt files.

Initialization of essential root files: README.md, requirements.txt, .gitignore, .env.example, CHANGELOG.md.

Python virtual environment (venv) setup integrated with .gitignore.

Detailed, timestamped logs with color-coded console outputs and robust error handling.

Safe script re-execution support.

User confirmation before any destructive cleanup.

Git Automation Script: git_push_changes.sh
Key Features
Interactive file staging, prompting per modified file.

Preview of unstaged and staged diffs for review before commit.

On-the-fly commit author override for flexible identity management.

Conditional safe push to remote only if commits exist.

GitHub API-based push verification using personal access tokens.

Automated generation of changelog files after successful push.

Optional display of recent commits summary in a clean tabular format.

Configurable logs directory structure organized by project.

Usage
Project Setup

chmod +x setup_project.sh
./setup_project.sh /your/target/path your_project_name


Cleanup Project

chmod +x cleanup_project.sh
./cleanup_project.sh /your/target/path your_project_name


Git Commit and Push Automation

chmod +x git_push_changes.sh
ksh git_push_changes.sh /absolute/path/to/your/project


Follow the interactive prompts for author override, file staging, commit message, and optional commit summaries.

Configuration
Create $HOME/config.env with:

export LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log"
export REPO_OWNER="your_github_username"
export GITHUB_TOKEN="your_personal_access_token"


Example Output Snippets

Override git author? (leave blank for default, or format 'Name <email>'):
John Doe <john@example.com>

Preview of Uncommitted Changes (git diff --stat):
  myscript.sh | 12 +++++-----
  1 file changed, 7 insertions(+), 5 deletions(-)

Stage? [ M] myscript.sh
Add this file? (yes/no): yes

Enter commit message:
Fixed critical parsing bug

Push completed!
Push verified on GitHub!
Generating change log for latest commits.
Changelog written to /media/karthik/WD-HDD/Learning/labs/log/myproject/CHANGELOG_20251017_120000.txt


Logging
Logs for all scripts reside in:

$LOG_BASE_DIR/<project_name>/

Typical files:

setup_project_testproject_YYYYMMDD_HHMMSS.log

cleanup_project_testproject_YYYYMMDD_HHMMSS.log

git_push_changes_YYYYMMDD_HHMMSS.log

Contribution
Open issues or submit pull requests for improvements, bug fixes, or new features. Your feedback and contributions are welcome.

Maintainer
Karthik KN.
