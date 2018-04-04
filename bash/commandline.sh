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

##
# Command line interface option information
#
CLI_OPT_SHORT=()
CLI_OPT_LONG=()
CLI_OPT_ARG=()
CLI_OPT_ARG_TYPE=()
CLI_OPT_DESC=()

##
# Command line interface argument types
#
CLI_INVALID_ARGUMENT=-1
CLI_NO_ARGUMENT=0
CLI_REQUIRED_ARGUMENT=1
CLI_OPTIONAL_ARGUMENT=2
CLI_LIST_ARGUMENT=3

CLIKEYS=()
CLIVALS=()

##
# Initialize the command line interface parser by storing all available options
# for the program.
#
cli_init()
{
    for line in "${@}"
    do
        local IFS=$'|'
        local options=(${line})
        cli_add_short_opt "${options[0]}"
        cli_add_long_opt "${options[1]}"
        if [ ${#options[@]} -eq 3 ]
        then
            cli_add_arg ""
        else
            cli_add_arg "${options[2]}"
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
    local opt=
    local arg=
    local index=
    local type=${CLI_INVALID_ARGUMENT}

    while [ -n "${1}" ]
    do
        index=$(cli_find_option_index "${1}")

        if cli_is_list_argument ${type}
        then
            if [ -z "${index}" ]
            then
                if [ -z "${arg}" ]
                then
                    arg="${1}"
                else
                    arg+="|${1}"
                fi
                shift
                continue
            else
                :
            fi
        fi

        if [ -z "${index}" ]
        then
            echo "${PROJECT}: Invalid option '${item}'."
            exit ${EARG}
        fi

        local item="${1}"
        echo "Item: '${item}'"

        type=$(cli_get_arg_type_index ${index})
        echo "Type: ${type}"

        if cli_is_no_argument ${type}
        then
            echo No argument
            opt="${item}"
            arg=""
            shift
        elif cli_is_required_argument ${type} \
                || cli_is_optional_argument ${type}
        then
            echo Required or optional

            opt="${item%%=*}"

            if cli_is_long_opt_index "${item}" "${index}"
            then
                arg="${item##*=}"
                if [ "${opt}" == "${arg}" ]
                then
                    if cli_is_required_argument ${type}
                    then
                        echo "${PROJECT}: Option '${opt}' must be supplied an argument." 1>&2
                        exit 2
                    fi
                    arg=
                    shift
                fi
            else
                shift
                if [ -n "$(cli_find_option_index "${1}")" ]
                then
                    if cli_is_required_argument ${type}
                    then
                        echo "${PROJECT}: Option '${opt}' must be supplied an argument." 1>&2
                        exit 2
                    fi
                    arg=
                else
                    arg="${1}"
                fi
            fi
        else
            echo "${PROJECT}: Unknown argument type for option ${opt}, type ${type}." 1>&2
            exit 1
        fi

        echo Adding stuff
        cli_add_key "${opt}"
        cli_add_value "${arg}"
        opt=
        arg=
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
    for i in $(cli_get_index_list)
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
    for i in $(cli_get_index_list)
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
    for i in $(cli_get_index_list_from_input)
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
    CLI_OPT_SHORT+=("${1// /}")
}

##
# Add a long option to the list of valid long options.
#
cli_add_long_opt()
{
    CLI_OPT_LONG+=("${1// /}")
}

##
# Add an argument name and type to the list of all argument names, as well as
# the list of all argument types.
#
cli_add_arg()
{
    local arg="${1// /}"
    local type=
    local count=$(echo "${arg}" | tr -c -d ':' | wc -c)
    case ${count} in
        0) type=${CLI_NO_ARGUMENT} ;;
        1) type=${CLI_REQUIRED_ARGUMENT} ;;
        2) type=${CLI_OPTIONAL_ARGUMENT} ;;
        3) type=${CLI_LIST_ARGUMENT} ;;
        *) echo "Error adding arg '${arg}'." 1>&2; exit ;;
    esac
    CLI_OPT_ARG+=("${arg//:/}")
    CLI_OPT_ARG_TYPE+=("${type}")
}

##
# Add a description to the list of descriptions.
#
cli_add_desc()
{
    CLI_OPT_DESC+=("${1}")
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
# Find the index of the option that corresponds to the input. The input must be
# a short or long option.
#
cli_find_option_index()
{
    local opt="${1}"
    local trunc="${1%%=*}"
    local i=
    for i in $(cli_get_index_list)
    do
        local short=$(cli_get_short_opt_index ${i})
        local long=$(cli_get_long_opt_index ${i})
        if cli_is_equal_opt "${opt}" "${short}" \
                || cli_is_equal_opt "${opt}" "${long}" \
                || cli_is_equal_opt "${trunc}" "${short}" \
                || cli_is_equal_opt "${trunc}" "${long}"
        then
            echo ${i}
            return 0
        fi
    done
    return 1
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
        for i in $(cli_get_index_list)
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
    echo "${CLI_OPT_SHORT[${1}]}"
}

##
# Return the long option at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_long_opt_index()
{
    echo "${CLI_OPT_LONG[${1}]}"
}

##
# Return the argument type at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_arg_type_index()
{
    echo "${CLI_OPT_ARG_TYPE[${1}]}"
}

##
# Return the argument name at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_arg_name_index()
{
    echo "${CLI_OPT_ARG[${1}]}"
}

##
# Return the description at the given index.
# 
# To-do: Add error checks for index number.
#
cli_get_desc_index()
{
    echo "${CLI_OPT_DESC[${1}]}"
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
    echo ${#CLI_OPT_DESC[@]}
}

##
# Return the number of options were input by the user into this program.
#
cli_get_n_input()
{
    echo ${#CLIKEYS[@]}
}

##
# Return a list of sequential indicies, ending in the last possible index in the
# list of options.
# 
# This is meant to be used to loop over all option information items.
#
cli_get_index_list()
{
    local n=$(cli_get_n_opt)
    if [ ${n} -eq 0 ]
    then
        return 1
    else
        seq 0 $[ ${n} - 1 ]
    fi
    return 0
}

##
# Return a list of sequential indicies, ending in the last possible index in the
# list of input supplied by the user.
# 
# This is meant to be used to loop over all option information items.
#
cli_get_index_list_from_input()
{
    local n=$(cli_get_n_input)
    if [ ${n} -eq 0 ]
    then
        return 1
    else
        seq 0 $[ ${n} - 1 ]
    fi
    return 0
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
# Check if the argument type is no_argument.
#
cli_is_no_argument()
{
    if [ "${1}" -eq ${CLI_NO_ARGUMENT} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is required_argument.
#
cli_is_required_argument()
{
    if [ "${1}" -eq ${CLI_REQUIRED_ARGUMENT} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is optional_argument.
#
cli_is_optional_argument()
{
    if [ "${1}" -eq ${CLI_OPTIONAL_ARGUMENT} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is list_argument.
#
cli_is_list_argument()
{
    if [ "${1}" -eq ${CLI_LIST_ARGUMENT} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the input string is equal to the option string. This function will
# also trim the option string, in case the input is in the key format.
# 
cli_is_equal_opt()
{
    local input="${1}"
    local opt="${2}"
    local trim=$(cli_trim_dash "${opt}")
    if [ "${input}" == "${opt}" -o "${input}" == "${trim}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# 
#
cli_is_short_opt()
{
    local opt="${1}"
    local index=$(cli_find_option_index "${opt}")
    return $(cli_is_short_opt_index "${opt}" "${index}")
}

##
# 
#
cli_is_short_opt_index()
{
    local opt="${1}"
    local index="${2}"
    if [ -z "${index}" ]
    then
        return 1
    fi
    local short=$(cli_get_short_opt_index ${index})
    if ! cli_is_equal_opt "${opt}" "${short}"
    then
        return 2
    fi
    return 0
}

##
# 
#
cli_is_long_opt()
{
    local opt="${1}"
    local index=$(cli_find_option_index "${opt}")
    return $(cli_is_long_opt_index "${opt}" "${index}")
}

##
# 
#
cli_is_long_opt_index()
{
    local opt="${1}"
    local index="${2}"
    if [ -z "${index}" ]
    then
        return 1
    fi
    local long=$(cli_get_long_opt_index ${index})
    if ! cli_is_equal_opt "${opt}" "${long}"
    then
        return 2
    fi
    return 0
}

