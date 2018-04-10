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

##
# Project name.
##
PROJECT=

##
# Command line interface option information.
##
CLI_OPTION_SHORT=()
CLI_OPTION_LONG=()
CLI_OPTION_ARGNAME=()
CLI_OPTION_ARGTYPE=()
CLI_OPTION_DESC=()

##
# Command line interface options and arguments that a user has input into the
# current running program.
##
CLI_INPUT_OPTION=()
CLI_INPUT_ARGUMENT=()

##
# Command line interface argument types.
##
CLI_ARGUMENT_TYPE_INVALID=-1
CLI_ARGUMENT_TYPE_NONE=0
CLI_ARGUMENT_TYPE_REQUIRED=1
CLI_ARGUMENT_TYPE_OPTIONAL=2
CLI_ARGUMENT_TYPE_LIST=3

##
# Define all the command line options and how they should be used.
# 
# When adding a long option, there will be a check for what the argument name
# and type are, if there is one.
##
cli_options()
{
    for line in "${@}"
    do
        local IFS=$'|'
        local options=(${line})
        local short="${options[0]}"
        local long="${options[1]}"
        local description="${options[2]}"
        local argument=

        cli_option_add_short "${short}"
        if cli_option_has_argument "${long}"
        then
            argument="$(cli_option_get_argument_field "${long}")"
            long="$(cli_option_get_option_field "${long}")"
            cli_option_add_argument "${argument}"
        fi
        cli_option_add_long "${long}"
        cli_option_add_description "${description}"
    done
    return 0
}

##
# Parse all command line options.
##
cli_parse()
{
    PROJECT="${0##*/}"
    local input=
    local opt=
    local arg=
    local index=
    local type=${CLI_ARGUMENT_TYPE_INVALID}

    while [ -n "${1}" ]
    do
        input="${1}"
        index=$(cli_find_option_index "${input}")
        if cli_parse_list_argument "${arg}" "${index}" "${type}"
        then
            arg="$(cli_add_list_argument "${arg}" "${input}")"
            shift
            if [ -z "${1}" ]
            then
                cli_add_to_table "${opt}" "${arg}"
            fi
            continue
        else
            if [ -n "${opt}" ]
            then
                cli_add_to_table "${opt}" "${arg}"
            fi
        fi
        if [ -z "${index}" ]
        then
            echo "${PROJECT}: Invalid option '${input}'."
            exit ${EARG}
        fi

        type=$(cli_get_arg_type_index ${index})
        opt="${index}"
        if cli_is_no_argument ${type}
        then
            arg=true
            cli_parse_help_opt "${input}"
            shift
        elif cli_is_required_argument ${type} \
                || cli_is_optional_argument ${type}
        then
            if cli_is_long_opt_index "${input}" "${index}"
            then
                arg="${input##*=}"
                if cli_parse_optional_long_argument "${input%%=*}" "${arg}" "${type}"
                then
                    arg=true
                fi
                shift
            else
                shift
                input="${1}"
                arg="${input}"
                if cli_parse_optional_short_argument "${input}" "${type}"
                then
                    arg=true
                else
                    shift
                fi
            fi
        elif cli_is_list_argument ${type}
        then
            shift
            cli_check_first_list_argument "${1}"
            continue
        else
            echo "${PROJECT}: Unknown argument type for option ${opt}, type ${type}." 1>&2
            exit 1
        fi

        cli_add_to_table "${opt}" "${arg}"
        opt=
        arg=
    done

    return 0
}

##
# Parse the help option.
##
cli_parse_help_opt()
{
    if [ "${1}" == "--help" ]
    then
        cli_usage
        exit 0
    fi
}

##
# Parse a list argument type.
##
cli_parse_list_argument()
{
    local arg="${1}"
    local index="${2}"
    local type="${3}"
    if cli_is_list_argument ${type}
    then
        if [ -z "${index}" ]
        then
            return 0
        fi
    fi
    return 1
}

##
# When a list argument type is encountered, check to make sure there are
# arguments present after it.
##
cli_check_first_list_argument()
{
    local input="${1}"
    local index=
    if [ -n "${input}" ]
    then
        index="$(cli_find_option_index "${input}")"
    fi
    if [ -z "${input}" ] || [ -n "${input}" -a -n "${index}" ]
    then
        echo "${PROJECT}: List argument needs at least one argument." 1>&2
        exit 3
    fi
}

##
# Parse an optional argument type.
##
cli_parse_optional_long_argument()
{
    local opt="${1}"
    local arg="${2}"
    local type="${3}"
    if [ "${opt}" == "${arg}" ]
    then
        if cli_is_required_argument ${type}
        then
            echo "${PROJECT}: Option '${opt}' must be supplied an argument." 1>&2
            exit 2
        fi
        return 0
    fi
    return 1
}

##
# Parse an optional argument
##
cli_parse_optional_short_argument()
{
    local input="${1}"
    local type="${2}"
    if [ -n "$(cli_find_option_index "${input}")" ]
    then
        if cli_is_required_argument ${type}
        then
            echo "${PROJECT}: Option '${opt}' must be supplied an argument." 1>&2
            exit 2
        fi
        return 0
    fi
    return 1
}

##
# Print the usage message for the program.
##
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
##
cli_get()
{
    local key=$(cli_opt_to_key "${1}")
    local i=
    if [ -z "${key}" ]
    then
        return 1
    fi
    for i in $(cli_get_table_index_list)
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
##
cli_test()
{
    local key=
    local val=
    local length=0
    local i=
    for i in $(cli_get_table_index_list)
    do
        key=$(cli_get_key_index ${i})
        if [ ${#key} -gt ${length} ]
        then
            length=${#key}
        fi
    done

    for i in $(cli_get_table_index_list)
    do
        key=$(cli_get_key_index ${i})
        val=$(cli_get_val_index ${i})
        printf "|Key: %${length}s | Value: %s|\n" "${key}" "${val}"
    done
}

##
# Add a key-value pair to the command line interface table.
##
cli_add_to_table()
{
    local index="${1}"
    local value="${2}"
    local opt=$(cli_get_long_opt_index ${index})
    local key=$(cli_opt_index_to_key ${index})
    CLI_INPUT_OPTION+=("${key}")
    CLI_INPUT_ARGUMENT+=("${value}")
}

##
# Add a key to the list of user provided options
##
cli_add_key()
{
    local opt="${1}"
    local key=$(cli_opt_to_key "${opt}")
    if [ -z "${key}" ]
    then
        echo "${PROJECT}: Something wrong with option '${opt}' to key."
        exit 1
    fi
    echo "Adding key: '${key}'."
    CLIKEYS+=("${key}")
}

##
# Add a value for the respective key. Should be used right after, or before,
# using cli_add_key.
##
cli_add_value()
{
    echo "Adding value: '${1}'."
    CLIVALS+=("${1}")
}

##
# Add an argument to the string containing the current list of arguments, for a
# list argument type.
##
cli_add_list_argument()
{
    local arg="${1}"
    local input="${2}"
    if [ -z "${arg}" ]
    then
        echo "${input}"
    else
        echo "${arg}|${input}"
    fi
}

##
# Create an option usage line
##
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
##
cli_find_option_index()
{
    local opt="${1}"
    local trunc="${1%%=*}"
    local i=
    if [ -z "${opt}" ]
    then
        return 1
    fi

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
# Convert an option to a key.
# 
# If a long option is not present, use a short option as the key. In either
# case, the leading dashes are removed.
##
cli_opt_to_key()
{
    local opt="${1}"
    local index=$(cli_find_option_index "${opt}")
    local key=
    if [ -z "${index}" ]
    then
        return 1
    fi
    key=$(cli_get_long_opt_index "${index}")
    if [ -z "${key}" ]
    then
        key=$(cli_get_short_opt_index "${index}")
    fi
    cli_trim_dash "${key}"
}

##
# Convert an option index to a key.
# 
# If a long option is not present, use a short option as the key. In either
# case, the leading dashes are removed.
##
cli_opt_index_to_key()
{
    local index="${1}"
    local opt=$(cli_get_long_opt_index ${index})
    if [ -z "${opt}" ]
    then
        opt=$(cli_get_short_opt_index ${index})
    fi
    if [ -z "${opt}" ]
    then
        echo "${PROJECT}: Unable to determine option string for index '${index}' and value '${value}'." 1>&2
        exit 4
    fi
    cli_trim_dash "${opt}"
}

##
# Trim dashes from option string.
##
cli_trim_dash()
{
    local trim="${1}"
    if [ "${trim:0:2}" == "--" ]
    then
        trim="${trim:2}"
    elif [ "${trim:0:1}" == "-" ]
    then
         trim="${trim:1}"
    else
        :
    fi
    echo "${trim}"
}

##
# Return the short option at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_short_opt_index()
{
    echo "${CLI_OPTION_SHORT[${1}]}"
}

##
# Return the long option at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_long_opt_index()
{
    echo "${CLI_OPTION_LONG[${1}]}"
}

##
# Return the argument type at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_arg_type_index()
{
    echo "${CLI_OPTION_ARGTYPE[${1}]}"
}

##
# Return the argument name at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_arg_name_index()
{
    echo "${CLI_OPTION_ARGNAME[${1}]}"
}

##
# Return the description at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_desc_index()
{
    echo "${CLI_OPTION_DESC[${1}]}"
}

##
# Return the key at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_key_index()
{
    echo "${CLI_INPUT_OPTION[${1}]}"
}

##
# Return the key's value at the given index.
# 
# To-do: Add error checks for index number.
##
cli_get_val_index()
{
    echo "${CLI_INPUT_ARGUMENT[${1}]}"
}

##
# Return the number of options that there are for this program.
##
cli_get_n_opt()
{
    echo ${#CLI_OPTION_DESC[@]}
}

##
# Return the number of options that were input by the user and added to the
# command line interface table.
##
cli_get_n_table_entries()
{
    echo ${#CLI_INPUT_OPTION[@]}
}

##
# Return a list of sequential indicies, ending in the last possible index in the
# list of options.
# 
# This is meant to be used to loop over all option information items.
##
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
##
cli_get_table_index_list()
{
    local n=$(cli_get_n_table_entries)
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
##
cli_has_arg()
{
    local opt="${1}"
    local i=
}

##
# Check if the argument type is no_argument.
##
cli_is_no_argument()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_NONE} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is required_argument.
##
cli_is_required_argument()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_REQUIRED} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is optional_argument.
##
cli_is_optional_argument()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_OPTIONAL} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is list_argument.
##
cli_is_list_argument()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_LIST} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the input string is equal to the option string. This function will
# also trim the option string, in case the input is in the key format.
## 
cli_is_equal_opt()
{
    local input="${1}"
    local opt="${2}"
    local trim=$(cli_trim_dash "${opt}")
    local trunc="${input%%=*}"
    if [ "${input}" == "${opt}" \
                    -o "${input}" == "${trim}" \
                    -o "${trunc}" == "${opt}" \
                    -o "${trunc}" == "${trim}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# 
##
cli_is_short_opt()
{
    local opt="${1}"
    local index=$(cli_find_option_index "${opt}")
    return $(cli_is_short_opt_index "${opt}" "${index}")
}

##
# 
##
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
##
cli_is_long_opt()
{
    local opt="${1}"
    local index=$(cli_find_option_index "${opt}")
    return $(cli_is_long_opt_index "${opt}" "${index}")
}

##
# 
##
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





















# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

##
# Add a short option to the list of valid short options.
##
cli_option_add_short()
{
    CLI_OPTION_SHORT+=("${1// /}")
}

##
# Add a long option to the list of valid long options.
##
cli_option_add_long()
{
    CLI_OPTION_LONG+=("${1// /}")
}

##
# Add an argument name and type to the list of all argument names, as well as
# the list of all argument types.
##
cli_option_add_argument()
{
    local arg="${1// /}"
    local type=
    local count=$(echo "${arg}" | tr -c -d ':' | wc -c)
    case ${count} in
        0) type=${CLI_ARGUMENT_TYPE_NONE} ;;
        1) type=${CLI_ARGUMENT_TYPE_REQUIRED} ;;
        2) type=${CLI_ARGUMENT_TYPE_OPTIONAL} ;;
        3) type=${CLI_ARGUMENT_TYPE_LIST} ;;
        *) echo "${PROJECT}: Error adding argument '${arg}'." 1>&2; exit ;;
    esac
    CLI_OPTION_ARGNAME+=("${arg//:/}")
    CLI_OPTION_ARGTYPE+=("${type}")
}

##
# Add a description to the list of descriptions.
##
cli_option_add_description()
{
    CLI_OPTION_DESC+=("${1}")
}




##
# Return the desired field from a long option that has an argument.
# 
# Example: '--long=argument'
# 
# Possible field values:
#   1 - The option field. From the example above, returns '--long'.
#   2 - The argument field. From the example above, returns 'argument'.
##
cli_option_get_field()
{
    local string="${1}"
    local field="${2}"
    case "${field}" in
        1) echo "${string%%=*}" ;;
        2) echo "${string##*=}" ;;
        *) return 1 ;;
    esac
    return 0
}

##
# Return the option field from a long option that has an argument.
##
cli_option_get_option_field()
{
    cli_option_get_field "${1}" 1
    return $?
}

##
# Return the argument field from a long option that has an argument.
##
cli_option_get_argument_field()
{
    cli_option_get_field "${1}" 2
    return $?
}

##
# Check if a provided option has an argument.
# 
# Used in cli_options(), checks if a long option is of the form
# '--long=argument', as opposed to an option having no argument, like '--long'.
##
cli_option_has_argument()
{
    local string="${1}"
    if [ "${string//=/}" != "${string}" ]
    then
        return 0
    else
        return 1
    fi
}
