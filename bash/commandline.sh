#!/bin/bash
# ------------------------------------------------------------------------------
# 
# File: commandline.sh
# Author: Gabriel Gonzalez
# Brief: Parse command line options in an easily definable manner.
# 
# Globals:
# 
#     * PROJECT - The name of the parent shell script.
# 
# Public functions:
# 
#     * cli_options
#     * cli_parse
#     * cli_test
#     * cli_get
#     * cli_usage
# 
# Private functions:
# 
#     * cli_option_add
#     * cli_input_add
#     * cli_parse_argument
#     * cli_parse_argument_none
#     * cli_parse_argument_required
#     * cli_parse_argument_optional
#     * cli_parse_argument_list
#     * cli_parse_argument_shift
#     * cli_usage_line
#     * cli_option_find
#     * cli_option_find_full
#     * cli_option_list
#     * cli_input_list
#     * cli_option_get_key
#     * cli_input_get_argument
#     * cli_input_get_argument_guess
#     * cli_option_get_field
#     * cli_option_get_option_field
#     * cli_option_get_argument_field
#     * cli_option_get_length
#     * cli_input_get_length
#     * cli_option_has_argument
#     * cli_option_is_long
#     * cli_argument_type_is_none
#     * cli_argument_type_is_required
#     * cli_argument_type_is_optional
#     * cli_argument_type_is_list
# 
# Exit codes:
# 
#     * EXIT_INVALID_ARGUMENT_TYPE = 1
#     * EXIT_INVALID_OPTION        = 2
#     * EXIT_INVALID_ARGUMENT      = 3
#     * EXIT_HELP                  = 4
#     * EXIT_OPTION_NOT_FOUND      = 5
#     * EXIT_INDEX_NOT_FOUND       = 6
#     * EXIT_OPTION_LENGTH_ZERO    = 7
#     * EXIT_INPUT_LENGTH_ZERO     = 8
#     * EXIT_INVALID_FIELD         = 9
#     * EXIT_INVALID_GET_OPTION    = 10
#     * EXIT_INVALID_GET_KEY       = 11
#     * EXIT_GET_OPTION_NOT_FOUND  = 12
# 
# ------------------------------------------------------------------------------

##
# The name of the project.
# 
# Determined by taking the basename of the parent shell script.
##
PROJECT=

##
# Command line interface option information.
##
declare -A CLI_OPTION
declare -A CLI_OPTION_MAP

##
# Command line interface options and arguments that a user has input into the
# current running program.
##
declare -A CLI_INPUT

##
# Command line interface argument types.
##
CLI_ARGUMENT_TYPE_INVALID=-1
CLI_ARGUMENT_TYPE_NONE=0
CLI_ARGUMENT_TYPE_REQUIRED=1
CLI_ARGUMENT_TYPE_OPTIONAL=2
CLI_ARGUMENT_TYPE_LIST=3

##
# List of exit statuses.
##
EXIT_INVALID_ARGUMENT_TYPE=1
EXIT_INVALID_OPTION=2
EXIT_INVALID_ARGUMENT=3
EXIT_HELP=4
EXIT_OPTION_NOT_FOUND=5
EXIT_INDEX_NOT_FOUND=6
EXIT_OPTION_LENGTH_ZERO=7
EXIT_INPUT_LENGTH_ZERO=8
EXIT_INVALID_FIELD=9
EXIT_INVALID_GET_OPTION=10
EXIT_INVALID_GET_KEY=11
EXIT_GET_OPTION_NOT_FOUND=12

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
        local key="${long}"
        local other="${short}"

        if [ -z "${long}" ]
        then
            key="${short}"
            other="${long}"
        else
            if cli_option_has_argument "${long}"
            then
                argument="$(cli_option_get_argument_field "${long}")"
                long="$(cli_option_get_option_field "${long}")"
                key="${long}"
            fi
        fi

        cli_option_add "${key}" "${other}" "${argument}" "${description}"
    done
    return 0
}

##
# Parse all the input command line options and arguments.
# 
# Options with no arguments will have an argument value of 'true', to indicate
# the option has been set. Options with a LIST argument type will have their
# values separated by a '|'.
# 
# Note: Parsing will also automatically catch the '--help' option. To change
# this functionality, see cli_parse_argument_none().
##
cli_parse()
{
    PROJECT="${0##*/}"

    while [ -n "${1}" ]
    do
        # Option information
        local opt="${1}"
        local info=($(cli_option_find "${opt}"))
        if [ $? -ne 0 ]
        then
            echo "${PROJECT}: Invalid option '${opt}'." 1>&2
            exit ${EXIT_INVALID_OPTION}
        fi

        # Parse the argument
        local key="${info[0]}"
        local type="${info[2]}"
        local arg=$(cli_parse_argument "${key}" "${type}" "${@}")
        local status=$?
        if [ ${status} -ne 0 ]
        then
            if [ ${status} -eq ${EXIT_HELP} ]
            then
                status=0
            fi
            exit ${status}
        fi

        # Add the argument(s) to the list of inputs
        cli_input_add "${key}" "${arg}"

        local skip=$(cli_parse_argument_shift "${opt}" "${arg}")
        shift ${skip}
        continue
    done

    return 0
}

##
# Test out which options have been entered on the command line.
##
cli_test()
{
    local key=
    local val=
    local length=0
    local opt=
    local arg=
    for opt in $(cli_input_list)
    do
        if [ ${#opt} -gt ${length} ]
        then
            length=${#key}
        fi
    done

    for opt in $(cli_input_list)
    do
        arg="$(cli_input_get_argument "${opt}")"
        printf "Key: %${length}s | Value: %s\n" "${opt}" "${arg}"
    done
}

##
# Return the value for the given option.
# 
# The input option must be a long option; however, if there is no long option,
# then the short option should be used.
##
cli_get()
{
    local opt="${1}"
    if [ "${opt:0:1}" == "-" ]
    then
        echo "${PROJECT}: Invalid option to retrieve. Do not use dashes when specifying the option." 1>&2
        return ${EXIT_INVALID_GET_OPTION}
    fi
    cli_input_get_argument_guess "${opt}"
    return $?
}

##
# Print the usage message for the program.
##
cli_usage()
{
    echo "Usage: ${PROJECT} [options]"
    echo
    echo "Options:"
    local opt=
    for opt in $(cli_option_list | sort)
    do
        local IFS=$'|'
        local full=($(cli_option_find_full "${opt}"))
        local key="${full[0]}"
        local other="${full[1]}"
        local desc="${full[3]}"
        local argname="${full[4]}"

        line=$(cli_usage_line "${key}" "${other}" "${argname}")
        echo "    ${line}"
        echo "        ${desc}" | fmt -c -w 80
        echo
    done
}

##
# Add an option to the list of valid options.
# 
# This will add the key option, the other option, the argument and its type, and
# the description.
# 
# Key         - Typically the long option, but if there is no long option, this
#               will be the short option.
# Other       - Typically the short option, but will be empty if the short
#               option is the Key.
# Argument    - This will be the argument name and its type, denoted by the
#               number of ':' after it.
# Description - Usage description for this option.
##
cli_option_add()
{
    local key="${1// /}"
    local other="${2// /}"
    local arg="${3// /}"
    local desc="${4}"
    local type=
    local count=$(echo "${arg}" | tr -c -d ':' | wc -c)
    case ${count} in
        0) type=${CLI_ARGUMENT_TYPE_NONE} ;;
        1) type=${CLI_ARGUMENT_TYPE_REQUIRED} ;;
        2) type=${CLI_ARGUMENT_TYPE_OPTIONAL} ;;
        3) type=${CLI_ARGUMENT_TYPE_LIST} ;;
        *) echo "${PROJECT}: Error adding argument '${arg}'." 1>&2
           exit ${EXIT_INVALID_ARGUMENT_TYPE}
           ;;
    esac
    if [ -n "${other}" ]
    then
        CLI_OPTION_MAP["${other}"]="${key}"
    fi
    CLI_OPTION["${key}"]="${other}|${type}|${desc}|${arg//:/}"
}

##
# Add the input option and corresponding argument to the list of inputs the
# user has entered on the command line.
##
cli_input_add()
{
    CLI_INPUT["${1}"]="${2}"
}

##
# Parse different argument types and return their argument.
##
cli_parse_argument()
{
    local key="${1}"
    local type="${2}"
    local opt="${3}"
    local arg=true
    local status=0
    shift 3

    if cli_argument_type_is_none "${type}"
    then
        arg="$(cli_parse_argument_none "${key}")" || return ${EXIT_HELP}
    elif cli_argument_type_is_required "${type}"
    then
        arg="$(cli_parse_argument_required "${opt}" "${1}")"
    elif cli_argument_type_is_optional "${type}"
    then
        arg="$(cli_parse_argument_optional "${opt}" "${1}")"
    elif cli_argument_type_is_list "${type}"
    then
        arg="$(cli_parse_argument_list "${opt}" "${@}")"
    else
        echo "${PROJECT}: Unknown argument type for option '${opt}', type '${type}'." 1>&2
        return 1
    fi

    status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi

    echo "${arg}"
}

##
# Parse an argument with the type NONE.
# 
# If the automatic detection of the '--help' option is not desired, just have
# this function echo "true" and return 0.
##
cli_parse_argument_none()
{
    local key="${1}"
    if [ "${key}" == "--help" ]
    then
        cli_usage 1>&2
        return 1
    fi
    echo "true"
    return 0
}

##
# Parse an argument with the type REQUIRED.
# 
# An argument is required. If there is no argument specified, return an error.
##
cli_parse_argument_required()
{
    local opt="${1}"
    local next="${2}"
    local arg="${next}"
    if cli_option_is_long "${opt}"
    then
        arg="$(cli_option_get_argument_field "${opt}")"
    else
        local nextinfo=($(cli_option_find "${next}"))
        if [ $? -eq 0 ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Parse an argument with the type OPTIONAL.
# 
# An argument is optional. If there is no argument specified, the argument is
# set to "true" to indicate it has been set.
##
cli_parse_argument_optional()
{
    local opt="${1}"
    local next="${2}"
    local arg="${next}"
    if cli_option_is_long "${opt}"
    then
        arg="$(cli_option_get_argument_field "${opt}")"
    else
        local nextinfo=($(cli_option_find "${next}"))
        if [ $? -eq 0 ]
        then
            arg="true"
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Parse an argument with the type LIST.
# 
# One or more arguments are required. If there is no argument set, return an
# error.
##
cli_parse_argument_list()
{
    local opt="${1}"
    shift
    local arg=

    if cli_option_is_long "${opt}"
    then
        # Make sure an argument was specified
        arg="$(cli_option_get_argument_field "${opt}")"
        if [ "${arg}" == "true" ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi
    else
        # Make sure next item is not an option
        local nextinfo=($(cli_option_find "${1}"))
        if [ $? -ne 0 ]
        then
            echo "${PROJECT}: An argument must be given for option '${opt}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi

        # Append options
        for a in "${@}"
        do
            if [ -z "${arg}" ]
            then
                arg="${a}"
            else
                arg="${arg}|${a}"
            fi
        done
    fi
    echo "${arg}"
    return 0
}

##
# Determine the number of times the argument list (${1}, ${2}, etc.) must be
# shifted.
##
cli_parse_argument_shift()
{
    local opt="${1}"
    local arg="${2}"
    local skip=
    if [ "${arg}" == "true" ] || cli_option_is_long "${opt}"
    then
        skip=1
    else
        skip=$[ $(echo "${arg}" | tr '|' '\n' | wc -l) + 1 ]
    fi
    echo "${skip}"
}

##
# Create a line in the usage message for the given option.
##
cli_usage_line()
{
    local key="${1}"
    local other="${2}"
    local argname="${3}"
    local line=
    if [ -n "${other}" ]
    then
        line="${other}"
    fi
    if [ -n "${key}" ]
    then
        if [ -n "${other}" ]
        then
            line+=", ${key}"
        else
            line="${key}"
        fi
    fi
    if [ -n "${argname}" ]
    then
        if [ -n "${key}" ]
        then
            line+="=<${argname}>"
        else
            line+=" <${argname}>"
        fi
    fi
    echo "${line}"
}

##
# Find the option information for the given option.
# 
# The input must be a short or long option key.
##
cli_option_find()
{
    local opt="${1}"
    local key="$(cli_option_get_key "${opt}")"
    local status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi
    local IFS=$'|'
    local info=(${CLI_OPTION["${key}"]})
    echo "${key} ${info[@]:0:3}"
    return 0
}

##
# Find the full option information (contains the description) for the given
# option.
# 
# The input must be a short or long option.  This is to be used when printing
# program usage because normally, the description is not needed.
##
cli_option_find_full()
{
    local opt="${1}"
    local key="$(cli_option_get_key "${opt}")"
    local status=$?
    if [ ${status} -ne 0 ]
    then
        return ${status}
    fi
    echo "${key}|${CLI_OPTION["${key}"]}"
    return 0
}

##
# Return a list of all options.
# 
# What is returned are the option keys. If there is a long option, this is the
# key, but if there is no long option, then the short option is the key.
##
cli_option_list()
{
    local n=$(cli_option_get_length)
    if [ ${n} -eq 0 ]
    then
        return ${EXIT_OPTION_LENGTH_ZERO}
    else
        echo "${!CLI_OPTION[@]}"
    fi
    return 0
}

##
# Return a list of all the input options.
##
cli_input_list()
{
    local n=$(cli_input_get_length)
    if [ ${n} -eq 0 ]
    then
        return ${EXIT_INPUT_LENGTH_ZERO}
    else
        echo "${!CLI_INPUT[@]}"
    fi
    return 0
}

##
# Return the option key that has an element in the associative array.
##
cli_option_get_key()
{
    if [ -z "${1}" ]
    then
        return ${EXIT_INVALID_GET_KEY}
    fi
    local key="$(cli_option_get_option_field "${1}")"
    local element="${CLI_OPTION["${key}"]}"
    if [ -z "${element}" ]
    then
        key="${CLI_OPTION_MAP["${key}"]}"
        element=(${CLI_OPTION["${key}"]})
    fi
    if [ -z "${element}" ]
    then
        return ${EXIT_OPTION_NOT_FOUND}
    fi
    echo "${key}"
}

##
# Return the input argument for the given option.
##
cli_input_get_argument()
{
    local arg="${CLI_INPUT[${1}]}"
    if [ -n "${arg}" ]
    then
        echo "${arg}"
        return 0
    else
        return ${EXIT_GET_OPTION_NOT_FOUND}
    fi
}

##
# Return the input argument for the given option, but guess as to what the
# option key is.
# 
# The guess work happens by prepending either '--' or '-' to the option.
##
cli_input_get_argument_guess()
{
    local arg="$(cli_input_get_argument "--${1}")"
    local status=$?
    if [ ${status} -ne 0 ]
    then
        arg="$(cli_input_get_argument "-${1}")"
        status=$?
        if [ ${status} -ne 0 ]
        then
            return ${status}
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Return the desired field from a long option that has an argument.
# 
# Example: '--long=argument'
# 
# Possible field values:
# 
#   1 - The option field. From the example above, returns '--long'.
#   2 - The argument field. From the example above, returns 'argument'.
##
cli_option_get_field()
{
    local string="${1}"
    local field="${2}"
    case "${field}" in
        1)
            echo "${string%%=*}"
            ;;

        2) if [ "${string//=/}" != "${string}" ]
           then
               echo "${string##*=}"
           else
               echo "true"
           fi
           ;;
        *)
            return ${EXIT_INVALID_FIELD}
            ;;
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
# Return the number of options that there are for this program.
##
cli_option_get_length()
{
    echo ${#CLI_OPTION[@]}
}

##
# Return the number of options that were input by the user.
##
cli_input_get_length()
{
    echo ${#CLI_INPUT[@]}
}

##
# Check if a provided long option has an argument.
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

##
# Check if the input option is a long option.
##
cli_option_is_long()
{
    local opt="${1}"
    if [ "${opt:0:2}" == "--" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is NONE type.
##
cli_argument_type_is_none()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_NONE} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is REQUIRED type.
##
cli_argument_type_is_required()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_REQUIRED} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is OPTIONAL type.
##
cli_argument_type_is_optional()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_OPTIONAL} ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the argument type is LIST type.
##
cli_argument_type_is_list()
{
    if [ "${1}" -eq ${CLI_ARGUMENT_TYPE_LIST} ]
    then
        return 0
    else
        return 1
    fi
}
