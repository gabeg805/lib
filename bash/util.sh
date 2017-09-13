#!/bin/bash
# ******************************************************************************
# 
# Name:    util.sh
# Author:  Gabriel Gonzalez
# Email:   gabeg@bu.edu
# License: The MIT License (MIT)
# 
# Syntax: . util.sh
# 
# Description: A compilation of utility functions that can be used by sourcing
#              this file.
# 
# Notes: To use some of the functionality, certain global variables are needed:
# 
#        - PROG    : Name of the program.
#        - PROGRAM : Same as PROG.
#        - VERBOSE : Verbose output.
#        - LOG     : Path of the log file.
#        - LOGFILE : Same as LOG.
# 
# ******************************************************************************

# Exit statuses
ENORM=0
EGETOPT=1
EARG=2
EARGS=2

# ******************************************************************************
# Print information
print_info()
{
    print_out ":: ${@}"
    log_out "info" "${@}"
    return 0
}

# ******************************************************************************
# Print warning
print_warn()
{
    print_out "~~ ${@}"
    log_out "warning" "${@}"
    return 0
}

# ******************************************************************************
# Print error
print_err()
{
    local prog="PROG"
    [ -n "${PROG}" ]     && prog="${PROG}"
    [ -n "${PROGRAM}" ]  && prog="${PROGRAM}"

    echo "${prog}: ${@}" 1>&2
    log_out "error" "${@}"
    return 0
}

# ******************************************************************************
# Print output
print_out()
{
    if [ -z "${VERBOSE}" ]; then
        return 1
    fi
    echo "${@}"
}

# ******************************************************************************
# Log output
log_out()
{
    if [ -n "${LOG}" -o -n "${LOGFILE}" ]; then
        local type="$(str_to_upper "${1}")"
        local log=
        shift
        [ -n "${LOG}" ]     && log="${LOG}"
        [ -n "${LOGFILE}" ] && log="${LOGFILE}"
        echo "[$(get_log_timestamp)] ${type}: ${@} >> ${log}" #>> "${log}"
    fi
}

# ******************************************************************************
# String to uppercase
str_to_upper()
{
    echo "${@}" | tr '[:lower:]' '[:upper:]'
}

# ******************************************************************************
# String to lowercase
str_to_lower()
{
    echo "${@}" | tr '[:upper:]' '[:lower:]'
}

# ******************************************************************************
# String to capitalize first letter and lowercase all other letters
str_to_capital()
{
    local str="${@}"
    if [ -z "${str}" ]; then
        return
    fi
    local firstchar=$(echo "${str:0:1}" | tr '[a-z]' '[A-Z]')
    local restchar=$(echo "${str:1}" | tr '[A-Z]' '[a-z]')
    echo "${firstchar}${restchar}"
}

# ******************************************************************************
# Return log timestamp
get_log_timestamp()
{
    local fmt="%F %T %z"
    date +"${fmt}"
}

# ******************************************************************************
# Check if value is integer
is_integer()
{
    if [ "${1}" -eq "${1}" ] 2>/dev/null; then
        return 0
    else
        return 1
    fi
}
