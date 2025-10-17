Project Setup & Cleanup Scripts
[![Shell Script](https://img.shields.io/badge(https://www.kornshell.comhttps://img.shields.io/badge
[![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen(https://github.com/karthikingithub/project_setup_repohttps://img.shields.io/badge(https://opensource.org/licenseshttps://img.shields.io/github/issues/karthikingithub/project(https://github.com/karthikingithub/project_setup_repohttps://img.shields.io/github/stars/karthikingithub/project_setup_repo.svg?style=social(https://github.com/karthikingithub/project_setup_repo

This repository contains Korn shell (ksh) scripts to efficiently setup and cleanup standardized project environments suitable for data engineering, AI workflows, or general software projects.

The scripts provide:

Modular creation of a comprehensive project folder structure with informative README.txt files in each folder.

Initialization of essential root files like README.md, requirements.txt, .gitignore, .env.example, and CHANGELOG.md.

Python virtual environment (venv) setup and integration with .gitignore.

Detailed logging mechanism with timestamped log files, color-coded console outputs, and robust error handling.

Safe re-execution with permission management.

User confirmation prior to destructive cleanup operations.

Git Automation Script: git_push_changes.sh
New in this repo:
An advanced interactive Git commit and push script with the following features:

Interactive file selection and staging for commits.

Uncommitted and staged changes diff previews before commit.

Custom commit author aliasing (temporarily override author name and email).

Safe, conditional push only if new commit exists.

Automated GitHub push verification (using GitHub API and personal access token).

Change log auto-generation after each push, saved as timestamped text files per project.

Clean console output with color-coded success/info/error messages.

Configurable logging directory structure organized by project.

Prompts for recent commit summaries displayed in clean tabular format.

Usage
Setup a new project
bash
chmod +x setup_project.sh
./setup_project.sh /your/target/path your_project_name
Cleanup an existing project
bash
chmod +x cleanup_project.sh
./cleanup_project.sh /your/target/path your_project_name
Git commit and push with automation
bash
chmod +x git_push_changes.sh
ksh git_push_changes.sh /absolute/path/to/your/project
Configuration
Create $HOME/config.env with:

bash
export LOG_BASE_DIR="/media/karthik/WD-HDD/Learning/labs/log"
export REPO_OWNER="your_github_username"
export GITHUB_TOKEN="your_github_personal_access_token"
Logging
All scripts write detailed logs under:

text
$LOG_BASE_DIR/<project_name>/
Example log files:

setup_project_test_project1_20251015_113000.log

cleanup_project_test_project1_cleanup_20251015_115000.log

git_push_changes_20251017_114500.log

Example Git Script Flow
text
Override git author? (leave blank for default, or format 'Name <email>'):
John Doe <john@example.com>

Preview of Uncommitted Changes (git diff --stat):
  myscript.sh | 10 +++++-----
  1 file changed, 5 insertions(+), 5 deletions(-)

Stage? [ M] myscript.sh
Add this file? (yes/no): yes

Enter commit message:
Fixed bug in parsing logic

Pushed origin/master
Push verified on GitHub!
Generating change log for latest commits.
Changelog written to /media/karthik/WD-HDD/Learning/labs/log/myproject/CHANGELOG_20251017_120000.txt
Repository Topics
shell-script ksh bash setup-script cleanup-script python-project data-engineering automation infrastructure boilerplate git-devops

Contact
Maintained by Karthik KN.

For questions, feature requests, or contributions, please open issues or pull requests.

Thank you for using these scripts! Feel free to customize to your organizational needs.

This enhanced README integrates your new git automation script smoothly while preserving coverage of core project setup and cleanup workflows. If you want me to format as a Markdown file or generate any images/badges, let me know!
