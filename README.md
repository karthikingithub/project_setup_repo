project_setup_repo/
│
├── setup_project.sh               # The ksh-compatible project setup script
├── README.md                     # Documentation for the script and usage
└── LICENSE                       # (Optional) License file if you want to share publicly

# Project Setup Script

This repository contains a Korn shell (`ksh`) compatible script `setup_project.sh` that automates setting up a standard, modular project folder structure with:

- Essential directories for airflow, db, src, config, scripts, data, and more
- Creation of `README.txt` files in each folder describing its purpose
- Initialization of key project root files (`README.md`, `requirements.txt`, `.gitignore`, `.env.example`, `CHANGELOG.md`)
- Setup of Python virtual environment inside `venv` folder
- Automatic update of `.gitignore` to exclude `venv/`
- Robust logging to timestamped log files saved under `/media/karthik/WD-HDD/Learning/labs/log/setup_project/`
- Terminal output with color-coded success, info, and error messages
- Idempotent operations safe to run multiple times with permission fixes (755) on directories

## Usage

1. Make the script executable:

chmod +x setup_project.sh

2. Run the script with root target path and project name arguments:

./setup_project.sh /desired/target/path your_project_name


Example:

./setup_project.sh /media/karthik/WD-HDD/Learning/labs test_project1


## Requirements

- Korn shell (`ksh`) installed and available in your environment
- Python 3 installed with `venv` module available
- Write permissions on the target directory and log base directory

## Logging

Logs are stored at:

/media/karthik/WD-HDD/Learning/labs/log/setup_project/setup_project_<project_name>_<timestamp>.log

#replace the log path as needed


Check these logs for details on the setup process including successes, info, and errors.

## Customization

You can modify the directories or README descriptions inside `setup_project.sh` function `create_directories()` as needed to fit your project requirements.

