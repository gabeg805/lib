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
# Store all available options for the program.
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
# Parse all command line options.
#
cli_parse()
{
    PROJECT="${0##*/}"
    local hasarg=false
    local opt=
    local arg=
    for item in "${@}"
    do
        echo "Item: '${item}'"
        if cli_is_long_opt "${item}"
        then
            cli_parse_help_opt "${item}"
            opt="${item%%=*}"
            arg="${item##*=}"
        elif cli_is_short_opt "${item}"
        then
            echo "Short opt!"
            hasarg=false
            opt="${item}"
            arg=""
            if cli_has_arg "${opt}"
            then
                echo "Has arg!"
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

        echo "Through!"

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
# Return the value for the given option.
#
cli_get()
{
    local key=$(cli_opt_to_key "${1}")
    local i=
    if [ -z "${key}" ]
    then
        return 1
    fi
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        if [ "$(cli_get_key_index ${i})" == "${key}" ]
        then
            echo "$(cli_get_val_index ${i})"
            return 0
        fi
    done
    return 2
}

##
# Test out which options have been entered.
#
cli_test()
{
    local key=
    local val=
    local i=
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        key=$(cli_get_key_index ${i})
        val=$(cli_get_val_index ${i})
        echo "Key: ${key} | Val: ${val}~"
    done
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
    echo "Adding key: '${key}'."
    CLIKEYS+=("${key}")
}

##
# Add a value for the respective key. Should be used right after, or before,
# using cli_add_key.
#
cli_add_value()
{
    echo "Adding value: '${1}'."
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
    if cli_is_long_opt "${opt}"
    then
        :
    elif cli_is_short_opt "${opt}"
    then
        local long=
        local i=
        for i in $(seq 0 $(cli_get_nsub1_opt))
        do
            long="$(cli_get_long_opt_index ${i})"
            if [ "${long}" == "${opt}" ]
            then
                opt="${long}"
                break
            fi
        done
    else
        return 1
    fi
    cli_trim_dash "${opt}"
}

##
# Trim dashes from option string.
#
cli_trim_dash()
{
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
# Return the key at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_key_index()
{
    echo "${CLIKEYS[${1}]}"
}

##
# Return the key's value at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_val_index()
{
    echo "${CLIVALS[${1}]}"
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
    local i=
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
    local short=
    local trim=
    local i=
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        short="$(cli_get_short_opt_index ${i})"
        trim="$(cli_trim_dash "${short}")"
        if [ "${short}" == "${input}" -o "${trim}" == "${input}" ]
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
    local trim=
    local long=
    local i=
    for i in $(seq 0 $(cli_get_nsub1_opt))
    do
        long="$(cli_get_long_opt_index ${i})"
        trim="$(cli_trim_dash "${long}")"
        if [ "${long}" == "${input}" -o "${long}" == "${trunc}" \
           -o "${trim}" == "${input}" -o "${trim}" == "${trunc}" ]
        then
            return 0
        fi
    done
    return 1
}
