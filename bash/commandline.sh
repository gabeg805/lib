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
#     * cli_input_add
#     * cli_option_add_short
#     * cli_option_add_long
#     * cli_option_add_argument
#     * cli_option_add_description
#     * cli_parse_argument
#     * cli_parse_argument_none
#     * cli_parse_argument_required
#     * cli_parse_argument_optional
#     * cli_parse_argument_list
#     * cli_parse_argument_shift
#     * cli_usage_line
#     * cli_option_find
#     * cli_option_find_with_index
#     * cli_option_index_list
#     * cli_input_index_list
#     * cli_option_get_short
#     * cli_option_get_long
#     * cli_option_get_argname
#     * cli_option_get_argtype
#     * cli_option_get_desc
#     * cli_input_get_option
#     * cli_input_get_argument
#     * cli_option_get_field
#     * cli_option_get_option_field
#     * cli_option_get_argument_field
#     * cli_option_get_length
#     * cli_input_get_length
#     * cli_option_has_argument
#     * cli_option_is_equal
#     * cli_option_is_short_compare
#     * cli_option_is_long_compare
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
#     * EXIT_GET_OPTION_NOT_FOUND  = 11
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
CLI_OPTION_SHORT=()
CLI_OPTION_LONG=()
CLI_OPTION_ARGNAME=()
CLI_OPTION_ARGTYPE=()
CLI_OPTION_DESC=()

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
EXIT_GET_OPTION_NOT_FOUND=11

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
        fi
        cli_option_add_argument "${argument}"
        cli_option_add_long "${long}"
        cli_option_add_description "${description}"
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
        if [ -z "${info}" ]
        then
            echo "${PROJECT}: Invalid option '${opt}'." 1>&2
            exit ${EXIT_INVALID_OPTION}
        fi

        # Parse the argument
        local index="${info[0]}"
        local long="${info[2]}"
        local arg=$(cli_parse_argument "${index}" "${@}")
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
        cli_input_add "${long}" "${arg}"

        local skip=$(cli_parse_argument_shift "${opt}" "${arg}" "${long}")
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
    local arg="$(cli_input_get_argument "--${opt}")"
    if [ -z "${arg}" ]
    then
        arg="$(cli_input_get_argument "-${opt}")"
        if [ -z "${arg}" ]
        then
            return ${EXIT_GET_OPTION_NOT_FOUND}
        fi
    fi
    echo "${arg}"
    return 0
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
    for i in $(cli_option_index_list)
    do
        short="$(cli_option_get_short "${i}")"
        long="$(cli_option_get_long "${i}")"
        argname="$(cli_option_get_argname "${i}")"
        desc="$(cli_option_get_desc "${i}")"
        line=$(cli_usage_line "${short}" "${long}" "${argname}")
        echo "    ${line}"
        echo "        ${desc}" | fmt -c -w 80
        echo
    done
}

##
# Add the input option and correspondding argument to the list of inputs the
# user has entered on the command line.
##
cli_input_add()
{
    CLI_INPUT["${1}"]="${2}"
}

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
# Add an argument name and type to the list of argument names, as well as to the
# list of argument types.
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
        *) echo "${PROJECT}: Error adding argument '${arg}'." 1>&2
           exit ${EXIT_INVALID_ARGUMENT_TYPE}
           ;;
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
# Parse different argument types and return their argument.
##
cli_parse_argument()
{
    local index="${1}"
    local info=($(cli_option_find_with_index "${index}"))
    local index="${info[0]}"
    local short="${info[1]}"
    local long="${info[2]}"
    local type="${info[3]}"
    local opt="${2}"
    local arg=true
    local status=0
    shift 2

    if cli_argument_type_is_none "${type}"
    then
        arg="$(cli_parse_argument_none "${long}")" || return ${EXIT_HELP}
    elif cli_argument_type_is_required "${type}"
    then
        arg="$(cli_parse_argument_required "${opt}" "${long}" "${1}")"
    elif cli_argument_type_is_optional "${type}"
    then
        arg="$(cli_parse_argument_optional "${opt}" "${long}" "${1}")"
    elif cli_argument_type_is_list "${type}"
    then
        arg="$(cli_parse_argument_list "${opt}" "${long}" "${@}")"
    else
        echo "${PROJECT}: Unknown argument type for option ${opt}, type ${type}." 1>&2
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
    local long="${1}"
    if [ "${long}" == "--help" ]
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
    local input="${1}"
    local long="${2}"
    local next="${3}"
    local arg="${next}"
    if cli_option_is_long_compare "${input}" "${long}"
    then
        arg="$(cli_option_get_argument_field "${input}")"
    else
        local nextinfo=($(cli_option_find "${next}"))
        if [ -n "${nextinfo}" ]
        then
            echo "${PROJECT}: An argument must be given for option '${input}'." 1>&2
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
    local input="${1}"
    local long="${2}"
    local next="${3}"
    local arg="${next}"
    if cli_option_is_long_compare "${input}" "${long}"
    then
        arg="$(cli_option_get_argument_field "${input}")"
    else
        local nextinfo=($(cli_option_find "${next}"))
        if [ -n "${nextinfo}" ]
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
    local input="${1}"
    local long="${2}"
    shift 2
    local arg=

    if cli_option_is_long_compare "${input}" "${long}"
    then
        # Make sure an argument was specified
        arg="$(cli_option_get_argument_field "${input}")"
        if [ "${arg}" == "true" ]
        then
            echo "${PROJECT}: An argument must be given for option '${input}'." 1>&2
            return ${EXIT_INVALID_ARGUMENT}
        fi
    else
        # Make sure next item is not an option
        local nextinfo=($(cli_option_find "${1}"))
        if [ -n "${nextinfo}" ]
        then
            echo "${PROJECT}: An argument must be given for option '${input}'." 1>&2
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
    local long="${3}"
    local skip=
    if [ "${arg}" == "true" ] || cli_option_is_long_compare "${opt}" "${long}"
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
# Find the option information for the given option.
# 
# The input must be a short or long option.
##
cli_option_find()
{
    local opt="${1}"
    local index=-1
    local i=0
    for i in $(cli_option_index_list)
    do
        local short=$(cli_option_get_short ${i})
        local long=$(cli_option_get_long ${i})
        if cli_option_is_equal "${opt}" "${short}" \
                || cli_option_is_equal "${opt}" "${long}"
        then
            index=${i}
            break
        fi
    done
    if [ ${index} -lt 0 ]
    then
        return ${EXIT_OPTION_NOT_FOUND}
    fi
    cli_option_find_with_index "${index}"
    return $?
}

##
# Find the option information using the index.
# 
# The input must be an index.
##
cli_option_find_with_index()
{
    local index="${1}"
    if [ -z "${index}" ]
    then
        return ${EXIT_INDEX_NOT_FOUND}
    fi
    local short="$(cli_option_get_short "${index}")"
    local long="$(cli_option_get_long "${index}")"
    local argtype="$(cli_option_get_argtype "${index}")"
    local argname="$(cli_option_get_argname "${index}")"
    local info=("${index}" "${short}" "${long}" "${argtype}" "${argname}")
    echo "${info[@]}"
    return 0
}

##
# Return a list of indicies used to loop over option information elements (short
# option, long option, argument names, etc.).
# 
# This list begins at 0 and ends at the number of options, subtracted by 1.
##
cli_option_index_list()
{
    local n=$(cli_option_get_length)
    if [ ${n} -eq 0 ]
    then
        return ${EXIT_OPTION_LENGTH_ZERO}
    else
        seq 0 $[ ${n} - 1 ]
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
# Return the short option at the given index.
# 
# To-do: Add error checks for index number.
##
cli_option_get_short()
{
    echo "${CLI_OPTION_SHORT[${1}]}"
}

##
# Return the long option at the given index.
# 
# To-do: Add error checks for index number.
##
cli_option_get_long()
{
    echo "${CLI_OPTION_LONG[${1}]}"
}

##
# Return the argument name at the given index.
# 
# To-do: Add error checks for index number.
##
cli_option_get_argname()
{
    echo "${CLI_OPTION_ARGNAME[${1}]}"
}

##
# Return the argument type at the given index.
# 
# To-do: Add error checks for index number.
##
cli_option_get_argtype()
{
    echo "${CLI_OPTION_ARGTYPE[${1}]}"
}

##
# Return the description at the given index.
# 
# To-do: Add error checks for index number.
##
cli_option_get_desc()
{
    echo "${CLI_OPTION_DESC[${1}]}"
}

##
# Return the input option at the given index.
# 
# To-do: Add error checks for index number.
##
cli_input_get_option()
{
    echo "${CLI_INPUT_OPTION[${1}]}"
}

##
# Return the input argument value at the given index.
# 
# To-do: Add error checks for index number.
##
cli_input_get_argument()
{
    echo "${CLI_INPUT[${1}]}"
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
    echo ${#CLI_OPTION_DESC[@]}
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
# Check if the input string is equal to the option string.
## 
cli_option_is_equal()
{
    local input="${1}"
    local opt="${2}"
    local field="$(cli_option_get_option_field "${input}")"
    if [ "${input}" == "${opt}" -o "${field}" == "${opt}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Compare the input to the actual short option.
# 
# The second input to this function should be the real short option.
##
cli_option_is_short_compare()
{
    local input="${1}"
    local short="${2}"
    if [ "${input}" == "${short}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Compare the input to the actual long option.
# 
# The second input to this function should be the real long option.
##
cli_option_is_long_compare()
{
    local input="${1}"
    local long="${2}"
    local field="$(cli_option_get_option_field "${input}")"
    if [ "${input}" == "${long}" -o "${field}" == "${long}" ]
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
