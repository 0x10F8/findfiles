#!/bin/sh
#
###############################################################################
# Utility searches for files on whether the current user can read/write them.
# Should hopefully be portable enough to work most places.
###############################################################################


# Constants
READ="r"
WRITE="w"
READ_WRITE="${READ}${WRITE}"

# Ignored directories
# Add more if you want or preferably just grep -v  the results
PROC=/proc/*

###############################################################################
# Find files in the specified directory based on the read/write status for the
# user running the script.
# Globals:
#   READ
#   WRITE
#   READ_WRITE
# Arguments:
#   $1 dir
#       The directory to search
#   $2 rw
#       The read/write status of the files to find (currently r/w/rw)
# Returns:
#   echo's the files matching the parameters specified to stdout
###############################################################################
find_files_in_dir() {
    local dir="$1"
    local rw="$2"
    # Iterate through the files in the directory
    for file in $(ls -Ap ${dir} | grep -v /); do
        local resolved_file="$(readlink -f ${dir}/${file})"
        # Ignore block devices and character files
        [ ! -b "${resolved_file}" ] && [ ! -c "${resolved_file}" ] && \
        case "$rw" in
            "$READ_WRITE")
                [ -r "${resolved_file}" ] && [ -w "${resolved_file}" ] && echo "${resolved_file}"
                ;;
            "$READ")
                [ -r "${resolved_file}" ] && echo "${resolved_file}"
                ;;
            "$WRITE")
                [ -w "${resolved_file}" ] && echo "${resolved_file}"
                ;;
            *)
                echo "[-] Unknown rw option ${rw}"
                return 1
                ;;
        esac
    done
    return 0
}

###############################################################################
# Find readable directories in the specified directory.
# Globals:
#   None
# Arguments:
#   $1 check_dir
#       The directory to search
# Returns:
#   echo's readable directories from the target directory
###############################################################################
find_dirs_in_dir() {
    local check_dir="$1"
    # Validate
    if [ -d ${check_dir} ]; then
        if [ ! -r ${dir} ]; then
            echo "[-] ${check_dir} is not accessible by this user"
            return 1
        fi
    else
        echo "[-] ${check_dir} is not a directory"
        return 1
    fi
    # Search
    for dir in $(ls -Ap ${check_dir} | grep /); do
        local resolved_dir="$(readlink -f ${check_dir}/${dir})/"
        # Filter ignored directories
        case "${resolved_dir}" in
            ${PROC})
            ;;
            *)
                [ -d ${resolved_dir} ] && [ -r ${resolved_dir} ] && echo "${resolved_dir}"
            ;;
        esac
    done
}

###############################################################################
# Find files in the specified directory based on the read/write status for the
# user running the script. Then recursively search the directories within the
# target directory using this function.
# Globals:
#   None
# Arguments:
#   $1 dir
#       The directory to search
#   $2 rw
#       The read/write status of the files to find (currently r/w/rw)
# Returns:
#   echo's the files matching the parameters specified to stdout
###############################################################################
recursively_find_files() {
    local dir="$1"
    local rw="$2"
    find_files_in_dir "${dir}" "${rw}"
    for next_dir in $(find_dirs_in_dir "${dir}"); do
        recursively_find_files "${next_dir}" "${rw}"
    done
}

# Print usage
usage() {
    echo "[-] Unknown options!"
    echo "Usage: ${0} [recursive_flag(optional)] [target_dir] [read/write/readwrite]"
    echo "  e.g. ${0} -r / w    -   Finds all writable files on whole system for run user"
    exit 1
}


# Command should be generally sh find_files.sh [recursive_flag] [target_dir] [read/write/readwrite]
# for example - sh find_files.sh -r / w

ARG_COUNT=$#
case ${ARG_COUNT} in
    2)
        # without recursive flag
        DIR="$(readlink -f $1)"
        RW="$2"
        ;;
    3)
        # with recursive flag
        [ "$1" = "-r" ] && RECURSIVE=0 || usage
        DIR="$(readlink -f $2)"
        RW="$3"
        ;;
    *)
        # Invalid argument count
        usage
        ;;
esac

# Execute command
if [ ${RECURSIVE} ]; then
    recursively_find_files "${DIR}" "${RW}"
else
    find_files_in_dir "${DIR}" "${RW}"
fi
