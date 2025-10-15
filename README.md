# Project Setup & Cleanup Scripts

[![Shell Script](https://img.shields.io/badge/shell-ksh-blue.svg)](https://www.kornshell.com/)  
[![Python 3](https://img.shields.io/badge/python-3.6%2B-blue.svg)](https://www.python.org/)  
[![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen.svg)](https://github.com/karthikingithub/project_setup_repo)  
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)  
[![Issues](https://img.shields.io/github/issues/karthikingithub/project_setup_repo.svg)](https://github.com/karthikingithub/project_setup_repo/issues)  
[![Stars](https://img.shields.io/github/stars/karthikingithub/project_setup_repo.svg?style=social)](https://github.com/karthikingithub/project_setup_repo/stargazers)

---

## Overview

This repository contains Korn shell (`ksh`) scripts to efficiently setup and cleanup standardized project environments suitable for data engineering, AI workflows, or general software projects.

The scripts provide:

- Modular creation of a comprehensive project folder structure with informative `README.txt` files in each folder.
- Initialization of essential root files like `README.md`, `requirements.txt`, `.gitignore`, `.env.example`, and `CHANGELOG.md`.
- Python virtual environment (`venv`) setup and integration with `.gitignore`.
- Detailed logging mechanism with timestamped log files, color-coded console outputs, and robust error handling.
- Safe re-execution with permission management.
- User confirmation prior to destructive cleanup operations.

---

## Scripts

### 1. `setup_project.sh`

Sets up a new project environment with all required directories, placeholder files, and Python virtual environment. Logs the entire process in the configured log directory.

### 2. `cleanup_project.sh`

Recursively deletes the entire project directory created by `setup_project.sh`, including the virtual environment and all contents. Requests explicit user confirmation before proceeding. Log files record every step and any errors.

---

## Usage

### Setup a new project

chmod +x setup_project.sh
./setup_project.sh /your/target/path your_project_name


### Cleanup an existing project


chmod +x cleanup_project.sh
./cleanup_project.sh /your/target/path your_project_name


You will be prompted to confirm deletion by typing `yes`.

---

## Logging

All script runs generate detailed logs stored here:


/media/karthik/WD-HDD/Learning/labs/log/<script_name>/


**Example log files:**

- `setup_project_test_project1_20251015_113000.log`
- `cleanup_project_test_project1_cleanup_20251015_115000.log`

Logs include timestamps, operation details, success info, and error diagnostics.

---

## Requirements

- Korn shell (`ksh`) installed and available
- Python 3 with `venv` module (for setup script)
- Write / delete permissions on the target and logs directories

---

## Repository Topics

You can classify this repository on GitHub by adding these topics:


shell-script ksh bash setup-script cleanup-script python-project data-engineering automation infrastructure boilerplate


---

## Contact

Maintained by **Karthik KN.**

For questions or contributions, please open issues or pull requests.

---

Thank you for using these scripts!  
Feel free to customize the directory structure and logging paths inside the scripts as per your organizational needs.


