#!/bin/ksh

# -----------------------------------------------------------------------------
# Script Name:
#   start_postgres_plsql.ksh
#
# Purpose:
#   Manage PostgreSQL service enabling, starting, stopping and disabling,
#   including executing a PLSQL block after start.
#   Reads DB credentials and logging path from $HOME/config.env.
#   Logs all operations with timestamps and colorful success/error feedback.
#
# Usage:
#   ./start_postgres_plsql.ksh
#
# Requirements:
#   - $HOME/config.env exporting the variables:
#       PG_DB_USER, PG_DATABASE, PG_DB_PASSWORD, LOG_BASE_DIR
#   - PostgreSQL service installed and accessible via systemctl and psql.
#
# Author:
#   Your Name or Identifier
#
# Date:
#   YYYY-MM-DD
# -----------------------------------------------------------------------------

# Functions for colored output in the terminal
colorgreen() { print "$(tput setaf 2)$*$(_reset_color)"; }
colorred() { print "$(tput setaf 1)$*$(_reset_color)" >&2; }
colorcyan() { print "$(tput setaf 6)$*$(_reset_color)"; }
_reset_color() { print "$(tput sgr0)"; }

# Logging function: logs all messages to a file; prints only errors/success to console
logmessage() {
  level=$1
  shift
  msg=$*
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  logline="[$timestamp] [$level] $msg"
  print "$logline" >>"$LOG_FILE"
  case "$level" in
    SUCCESS) colorgreen "$logline" ;;
    ERROR) colorred "$logline" ;;
    *) ;;  # Do not print INFO level to console
  esac
}

# Loads configuration variables from $HOME/config.env and validates them
load_config() {
  if [ ! -f "$HOME/config.env" ]; then
    print "ERROR: Missing configuration file $HOME/config.env." >&2
    exit 1
  fi
  . "$HOME/config.env"

  if [ -z "$PG_DB_USER" ]; then
    print "ERROR: PG_DB_USER not set in config." >&2
    exit 1
  fi
  if [ -z "$PG_DATABASE" ]; then
    print "ERROR: PG_DATABASE not set in config." >&2
    exit 1
  fi
  if [ -z "$PG_DB_PASSWORD" ]; then
    print "ERROR: PG_DB_PASSWORD not set in config." >&2
    exit 1
  fi
  if [ -z "$LOG_BASE_DIR" ]; then
    print "ERROR: LOG_BASE_DIR not set in config." >&2
    exit 1
  fi
}

# Enables PostgreSQL service if not already enabled
enable_postgres() {
  if sudo systemctl is-enabled --quiet postgresql; then
    logmessage INFO "PostgreSQL service already enabled."
  else
    logmessage INFO "Enabling PostgreSQL service..."
    if sudo systemctl enable postgresql >>"$LOG_FILE" 2>&1; then
      logmessage SUCCESS "PostgreSQL service enabled."
    else
      logmessage ERROR "Failed to enable PostgreSQL service."
      return 1
    fi
  fi
  return 0
}

# Starts PostgreSQL service if not already running
start_postgres() {
  if sudo systemctl is-active --quiet postgresql; then
    logmessage INFO "PostgreSQL service already running."
  else
    logmessage INFO "Starting PostgreSQL service..."
    if sudo systemctl start postgresql >>"$LOG_FILE" 2>&1; then
      logmessage SUCCESS "PostgreSQL service started."
    else
      logmessage ERROR "Failed to start PostgreSQL service."
      return 1
    fi
  fi
  return 0
}

# Stops and disables PostgreSQL service if running and enabled
stop_postgres() {
  if sudo systemctl is-active --quiet postgresql; then
    logmessage INFO "Stopping PostgreSQL service..."
    if sudo systemctl stop postgresql >>"$LOG_FILE" 2>&1; then
      logmessage SUCCESS "PostgreSQL service stopped."
    else
      logmessage ERROR "Failed to stop PostgreSQL service."
      return 1
    fi
  else
    logmessage INFO "PostgreSQL service already stopped."
  fi

  if sudo systemctl is-enabled --quiet postgresql; then
    logmessage INFO "Disabling PostgreSQL service..."
    if sudo systemctl disable postgresql >>"$LOG_FILE" 2>&1; then
      logmessage SUCCESS "PostgreSQL service disabled."
    else
      logmessage ERROR "Failed to disable PostgreSQL service."
      return 1
    fi
  else
    logmessage INFO "PostgreSQL service already disabled."
  fi
  return 0
}

# Executes a PLSQL block and logs all output to the log file
run_plsql() {
  logmessage INFO "Executing PLSQL block..."
  export PGPASSWORD="$PG_DB_PASSWORD"
  if psql -U "$PG_DB_USER" -d "$PG_DATABASE" -c "
  DO \$\$
  BEGIN
    RAISE NOTICE 'PLSQL block executed successfully after database startup.';
  END
  \$\$;
  " >>"$LOG_FILE" 2>&1; then
    logmessage SUCCESS "PLSQL block executed successfully."
  else
    logmessage ERROR "PLSQL block execution failed."
    return 1
  fi
  unset PGPASSWORD
  return 0
}

# Main orchestration function with input validation loop
main() {
  load_config

  SCRIPT_NAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_DIR="${LOG_BASE_DIR}/${SCRIPT_NAME}"

  mkdir -p "$LOG_DIR" || { colorred "ERROR: Cannot create log directory $LOG_DIR"; exit 1; }

  LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"

  logmessage INFO "Configuration loaded and logging initialized."

  while :; do
    print "Please select an option:"
    print "1. Start PostgreSQL and run PLSQL"
    print "2. Stop and disable PostgreSQL"
    print -n "Enter choice [1 or 2]: "
    read choice

    case "$choice" in
      1)
        if enable_postgres && start_postgres && run_plsql; then
          logmessage SUCCESS "PostgreSQL started and PLSQL executed successfully."
          break
        else
          logmessage ERROR "Error during PostgreSQL start or PLSQL execution."
          exit 1
        fi
        ;;
      2)
        if stop_postgres; then
          logmessage SUCCESS "PostgreSQL stopped and disabled successfully."
          break
        else
          logmessage ERROR "Error during PostgreSQL stop or disable."
          exit 1
        fi
        ;;
      *)
        logmessage ERROR "Invalid input. Please enter 1 or 2."
        ;;
    esac
  done
}

main "$@"
