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

    # if cli_argument_type_is_none "${type}"
    # then
    #     cli_parse_help_option "${input}"
    # elif cli_argument_type_is_required "${type}" || cli_argument_type_is_optional "${type}"
    # then
    #     if cli_option_is_long_compare "${input}" "${long}"
    #     then
    #         if cli_argument_type_is_required "${type}"
    #         then
    #             arg="$(cli_option_get_argument_field "${input}")"
    #         fi
    #     else
    #         shift
    #         local newinfo=($(cli_option_find_with_index "${1}"))
    #         if [ -n "${newinfo}" ]
    #         then
    #             if cli_argument_type_is_optional "${type}"
    #             then
    #                 :
    #             else
    #                 # ERROR
    #             fi
    #         else
    #             arg="${1}"
    #         fi
    #     fi
    # elif cli_argument_type_is_list "${type}"
    # then
    #     shift
    #     cli_check_first_list_argument "${1}"
    #     continue
    # else
    #     echo "${PROJECT}: Unknown argument type for option ${opt}, type ${type}." 1>&2
    #     exit 1
    # fi



##
# Parse all command line options.
##
cli_parse()
{
    PROJECT="${0##*/}"
    local info=()
    local input=
    local skip=1

    while [ -n "${1}" ]
    do
        input="${1}"
        info=($(cli_option_find "${input}"))
        if [ -z "${info}" ]
        then
            echo "${PROJECT}: Invalid option '${input}'."
            exit ${EARG}
        fi

        skip=$(cli_parse_argument "${input}" "${info[0]}" "${@}")
        if [ $? -ne 0 ]
        then
            exit ${EARG}
        fi
        shift ${skip}
        continue
    done

    return 0
}

##
# Parse different argument types.
##
cli_parse_argument()
{
    local input="${1}"
    local index="${2}"
    local info=($(cli_option_find_with_index "${index}"))
    local short="${info[1]}"
    local long="${info[2]}"
    local type="${info[3]}"
    local opt="${long}"
    local arg=true
    local skip=1
    local status=0
    shift 2

    if cli_argument_type_is_none "${type}"
    then
        arg="$(cli_parse_argument_none "${long}")" || exit 0
    elif cli_argument_type_is_required "${type}"
    then
        arg="$(cli_parse_argument_required "${input}" "${long}" "${2}")"
        status=$?
    elif cli_argument_type_is_optional "${type}"
    then
        arg="$(cli_parse_argument_optional "${input}" "${long}" "${2}")"
        status=$?
    elif cli_argument_type_is_list "${type}"
    then
        arg="$(cli_parse_argument_list "${input}" "${long}" "${@}")"
        status=$?
    else
        echo "${PROJECT}: Unknown argument type for option ${opt}, type ${type}." 1>&2
        exit 1
    fi

    if [ $? -ne 0 ]
    then
        exit 1
    fi

    echo "${skip}"
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
        index="$(cli_option_find_index "${input}")"
    fi
    if [ -z "${input}" ] || [ -n "${input}" -a -n "${index}" ]
    then
        echo "${PROJECT}: List argument needs at least one argument." 1>&2
        exit 3
    fi
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
cli_input_add()
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
# Convert an option to a key.
# 
# If a long option is not present, use a short option as the key. In either
# case, the leading dashes are removed.
##
cli_opt_to_key()
{
    local opt="${1}"
    local index=$(cli_option_find_index "${opt}")
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
# Check if the input string is equal to the option string. This function will
# also trim the option string, in case the input is in the key format.
## 
cli_is_equal_opt()
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
# 
##
cli_is_short_opt()
{
    local opt="${1}"
    local index=$(cli_option_find_index "${opt}")
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
    local index=$(cli_option_find_index "${opt}")
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
# Parse an argument with the type NONE.
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
        local nextinfo=($(cli_option_find_with_index "${next}"))
        if [ -n "${nextinfo}" ]
        then
            echo "${PROJECT}: An argument must be given for option '${input}'." 1>&2
            return 1
        fi
    fi
    echo "${arg}"
    return 0
}

##
# Parse an argument with the type OPTIONAL.
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
        local nextinfo=($(cli_option_find_with_index "${next}"))
        if [ -n "${nextinfo}" ]
        then
            arg="true"
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
    for i in $(cli_get_index_list)
    do
        short="$(cli_option_get_short "${i}")"
        long="$(cli_option_get_long "${i}")"
        argname="$(cli_option_get_argname "${i}")"
        desc="$(cli_option_get_desc "${i}")"
        line=$(cli_new_usage_line "${short}" "${long}" "${argname}")
        echo "    ${line}"
        echo "        ${desc}" | fmt -c -w 80
        echo
    done
}

##
# Create a usage line for the given option.
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
# Find the option information for the given input.
# 
# The input must be a short or long option.
##
cli_option_find()
{
    local opt="${1}"
    local index="$(cli_option_find_index "${opt}")"
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
        return 1
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
    local 
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
            return 1
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

##
# Compare the input to the actual short option.
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
