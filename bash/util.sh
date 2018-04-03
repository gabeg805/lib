#!/bin/bash
# ------------------------------------------------------------------------------
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
# ------------------------------------------------------------------------------

# Exit statuses
PROJECT=
ENORM=0
EGETOPT=1
EARG=2
EARGS=2

CLIOPTSHORT=()
CLIOPTLONG=()
CLIOPTARG=()
CLIOPTDESC=()

CLIKEYS=()
CLIVALS=()
CLIARGTYPES=()

##
#
#
cli_options()
{
    for line in "${@}"
    do
        local IFS=$'|'
        local options=(${line})
        cli_add_short_opt "${options[0]}"
        cli_add_long_opt "${options[1]}"
        if [ ${#options[@]} -eq 3 ]
        then
            cli_add_arg_name "none"
        else
            cli_add_arg_name "${options[2]}"
        fi
        cli_add_desc "${options[-1]}"
    done
    return 0
}

##
#
#
cli_parse()
{
    PROJECT="${0##*/}"
    local hasarg=false
    local opt=
    local arg=
    for item in "${@}"
    do
        echo "Has: ${hasarg}"
        echo "Item: ${item}"

        if cli_is_long_opt "${item}"
        then
            cli_parse_help_opt "${item}"
            opt="${item%%=*}"
            arg="${item##*=}"
        elif cli_is_short_opt "${item}"
        then
            hasarg=false
            opt="${item}"
            arg=""
            if cli_has_arg "${opt}"
            then
                hasarg=true
                continue
            fi
        else
            if ! ${hasarg}
            then
                echo "${PROJECT}: Invalid option '${item}'." 1>&2
                exit ${EARG}
            else
                arg="${item}"
            fi
        fi

        cli_add_key "${opt}"
        cli_add_value "${arg}"
    done

    return 0
}

##
# Parse the help option.
#
cli_parse_help_opt()
{
    if [ "${1}" == "--help" ]
    then
        cli_usage
        exit 0
    fi
}

##
# Print the usage message for the program.
#
cli_usage()
{
    local short=
    local long=
    local argname=
    local desc=
    local line=
    local i=
    echo "Usage: ${PROJECT} [options]"
    echo
    echo "Options:"
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        short=$(cli_get_short_opt_index ${i})
        long=$(cli_get_long_opt_index ${i})
        argname=$(cli_get_arg_name_index ${i} | tr -d ':')
        desc=$(cli_get_desc_index ${i})
        line=$(cli_new_usage_line "${short}" "${long}" "${argname}")
        echo "    ${line}"
        echo "        ${desc}" | fmt -c -w 80
        echo
    done
}

##
# Test out which options have been entered.
#
cli_test()
{
    :
}

##
# Add a short option to the list of valid short options.
#
cli_add_short_opt()
{
    CLIOPTSHORT+=("${1// /}")
}

##
# Add a long option to the list of valid long options.
#
cli_add_long_opt()
{
    CLIOPTLONG+=("${1// /}")
}

##
# Add an argument name (as well as the ':' type information) to the list of all
# argument names.
#
cli_add_arg_name()
{
    CLIOPTARG+=("${1// /}")
}

##
# Add a description to the list of descriptions.
#
cli_add_desc()
{
    CLIOPTDESC+=("${1}")
}

##
# Add a key to the list of user provided options
#
cli_add_key()
{
    local opt="${1}"
    local key=$(cli_opt_to_key "${opt}")
    if [ -z "${key}" ]
    then
        echo "${PROJECT}: Something wrong with option to key."
        exit 1
    fi
    CLIKEYS+=("${key}")
}

##
# Add a value for the respective key. Should be used right after, or before,
# using cli_add_key.
#
cli_add_value()
{
    CLIVALS+=("${1}")
}

##
# Create an option usage line
#
cli_new_usage_line()
{
    local short="${1}"
    local long="${2}"
    local argname="${3}"
    local line=
    if [ -n "${short}" ]
    then
        line="${short}"
    fi
    if [ -n "${long}" ]
    then
        if [ -n "${short}" ]
        then
            line+=", ${long}"
        else
            line="${long}"
        fi
    fi
    if [ "${argname}" != "none" ]
    then
        if [ -n "${long}" ]
        then
            line+="=<${argname}>"
        else
            line+=" <${argname}>"
        fi
    fi
    echo "${line}"
}

##
# Convert an option to a key. If a long option is not present, use a short
# option as the key. In either case, the leading dashes are removed.
#
cli_opt_to_key()
{
    local opt="${1}"
    if cli_is_opt "${opt}"
    then
        :
    else
        return 1
    fi
    echo "${1}" | sed -re 's/^[-][-]?//'
}

##
# Return the short option at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_short_opt_index()
{
    echo "${CLIOPTSHORT[${1}]}"
}

##
# Return the long option at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_long_opt_index()
{
    echo "${CLIOPTLONG[${1}]}"
}

##
# Return the argument name at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_arg_name_index()
{
    echo "${CLIOPTARG[${1}]}"
}

##
# Return the description at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_desc_index()
{
    echo "${CLIOPTDESC[${1}]}"
}

##
# Return the number of options that there are for this program.
#
cli_get_n_opt()
{
    echo ${#CLIOPTDESC[@]}
}

##
# Return the number of options that there are for this program, subtracted by 1,
# for looping.
#
cli_get_nsub1_opt()
{
    echo $[ ${#CLIOPTDESC[@]} - 1 ]
}

##
# Check if the given command line option takes an argument
#
cli_has_arg()
{
    local opt="${1}"
}

##
# Check if input is an option
#
cli_is_opt()
{
    if cli_is_short_opt "${1}" || cli_is_long_opt "${1}"
    then
        return 0
    else
        return 1
    fi
}

##
# Check if input is a short option
#
cli_is_short_opt()
{
    local input="${1}"
    local i=
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        if [ "$(cli_get_short_opt_index ${i})" == "${input}" ]
        then
            return 0
        fi
    done
    return 1
}

##
# Check if input is a long option
#
cli_is_long_opt()
{
    local input="${1}"
    local trunc="${input%%=*}"
    local short=
    local i=
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        short="$(cli_get_long_opt_index ${i})"
        if [ "${short}" == "${input}" ] || [ "${short}" == "${trunc}" ]
        then
            return 0
        fi
    done
    return 1
}

##
#
#
parse_options()
{
    local program="${1}"
    local short="${2}"
    local long="${3}"
    shift 3
    if [ $# -eq 0 ]
    then
        usage
        exit ${ENORM}
    fi

    local args=$(getopt -o "${short}" --long "${long}" --name "${PROGRAM}" -- "${@}")
    if [ $? -ne 0 ]
    then
        usage
        exit ${EGETOPT}
    fi
    eval set -- "${args}"
}

# ------------------------------------------------------------------------------
# Print information
print_info()
{
    print_out ":: ${@}"
    log_out "info" "${@}"
    return 0
}

# ------------------------------------------------------------------------------
# Print warning
print_warn()
{
    print_out "~~ ${@}"
    log_out "warning" "${@}"
    return 0
}

# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Print output
print_out()
{
    if [ -z "${VERBOSE}" ]; then
        return 1
    fi
    echo "${@}"
}

# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# String to uppercase
str_to_upper()
{
    echo "${@}" | tr '[:lower:]' '[:upper:]'
}

# ------------------------------------------------------------------------------
# String to lowercase
str_to_lower()
{
    echo "${@}" | tr '[:upper:]' '[:lower:]'
}

# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Return log timestamp
get_log_timestamp()
{
    local fmt="%F %T %z"
    date +"${fmt}"
}

# ------------------------------------------------------------------------------
# Check if value is integer
is_integer()
{
    if [ "${1}" -eq "${1}" ] 2>/dev/null; then
        return 0
    else
        return 1
    fi
}
