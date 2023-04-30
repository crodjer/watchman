#!/usr/bin/env bash

PROGRAM_NAME=$(basename $0)

_HELP_VERBOSE=`cat <<EOF
Usage:

    $PROGRAM_NAME [OPTIONS] <FILE PATTERNS> -- <COMMAND>
    $PROGRAM_NAME [OPTIONS] <FILE NAME> <COMMAND>

OPTIONS
-------

 -h          Show detailed help
 -v          Verbose output
 -x PATTERN  Exclude files matching PATTERN (POSIX extended regular expression)
 -r          Watch files recursively
 -b          Beep when command execution fails

FILE PATTERNS
-------------
Space separated file names/patterns which are to be watched by 'watchman'. This
can also be a directory, in which case, all the files will be watched for
changes.

COMMAND
-------
The command which is to be executed when a change is triggered. Since, watchman
can watch multiple files, there are a few file placeholders available which will
be filled in appropriately at execution time. To use a placeholder just write it
in braces in your command.  Eg: {dir_name}/{base_prefix}.out


PLACEHOLDERS
------------
The following placeholders are available to be used in a command.

**file**  
The relative path to the file from current directory. Eg: ./foo/bar/foobar.baz

**base_name**  
The base name of the file. Eg: foobar.baz

**dir_name**  
The relative path to the directory file is in. Eg: ./foo/bar/

**base_prefix**  
The file name without the file extension. Eg: foobar

WATCHING SINGLE FILES
---------------------
In case you only have a single file as watch target, the delimter '--' can be
skipped.
EOF
`
_HELP=`cat <<EOF
Usage: $PROGRAM_NAME [OPTIONS] <FILE PATTERNS> -- <COMMAND>
Use $PROGRAM_NAME -h for more help.
EOF
`

_DEFAULT_EXCLUDES='.git/index.lock foo'

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
FACE_RESET=$(tput sgr0)

color () {
    case $1 in
        red)
            _col=$RED
            ;;
        yellow)
            _col=$YELLOW
            ;;
        green)
            _col=$GREEN
            ;;
        *)
            _col=$FACE_RESET
    esac

    printf $_col
}

show_help () {
    if [[ "$1" == "stdin" ]]; then
        echo "$_HELP_VERBOSE"
    else
        color yellow
        printf "\n$_HELP\n" >&2
    fi

    color reset
}

stderr () {
    color yellow
    printf "$@\n" >&2
    color reset
}

error () {
    color red
    printf "$@\n"
    color reset
}

success () {
    color green
    printf "$@\n"
    color reset
}

add_exclude () {
    if [[ -z "$inotify_exclude" ]]; then
        inotify_exclude="($1)"
    else
        inotify_exclude="($1)|$inotify_exclude"
    fi
}

while getopts :hvrbx: opt; do
    case $opt in
        v)
            verbose=1
            ;;
        h)
            show_help stdin
            exit 0
            ;;
        r)
            inotify_bool_flags="r$inotify_bool_flags"
            ;;
        x)
            add_exclude $OPTARG
            ;;
        b)
            bell_on_error=1
            ;;
        \?)
            error "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
    esac
done

for _exclude in $_DEFAULT_EXCLUDES; do
    add_exclude $_exclude
done

shift $(($OPTIND-1))

args="$@"

if [[ "$args" == "" ]]; then
    error "No arguments provided" >&2
    show_help
    exit 1
fi

# In case the delimiter `--` is not present, assume that only one file was
# provided and take rest all as a command
if [[ "$args" != *" -- "* ]]; then
    args="$(echo $args | sed 's/ / -- /')"
fi

set -- $args

while [ $# -gt 0 ]; do
    case $1 in
        (--)
            shift
            command="$@"
            break
            ;;
        (*)
            files="$1 $files"
            shift
    esac
done

if [[ "$files" == "" ]]; then
    error "No files provided to watch on." >&2
    show_help
    exit 1
fi

if [[ "$command" == "" ]]; then
    error "Command should not be blank." >&2
    show_help
    exit 1
fi

if [ -z "$verbose" ]; then
    inotify_bool_flags="q$inotify_bool_flags"
fi

if [[ "$inotify_bool_flags" ]]; then
    inotify_bool_flags="-$inotify_bool_flags"
fi

if [[ "$inotify_exclude" ]]; then
    inotify_exclude="--exclude $inotify_exclude"
fi


inotify_events="-e modify,attrib,moved_to,create,delete"
inotify_flags="$inotify_bool_flags -m --timefmt %s --format %T|%e|%w%f"
inotify_cmd="inotifywait $inotify_flags $inotify_events $inotify_exclude $files"

if [[ "$verbose" ]]; then
    stderr "Will watch: $files"
fi

# Make stderr yellow
color yellow
$inotify_cmd | while read key; do

    _cut () {
        echo $key | cut -d '|' -f $@
    }

    timestamp=$(_cut 1)
    events=$(_cut 2)
    file=$(_cut 3-)
    base_name=$(basename $file)
    dir_name=$(dirname $file)
    base_prefix=${base_name%%.*}

    if [ "$_prev_key" != "$key" ]; then
        # This helps us prevent firing the command multiple times, because
        # inotify raises multiple events
        _prev_key="$key"

        color yellow

        if [[ "$verbose" ]]; then
            stderr "[$(date)] $base_name: $events"
        fi

        color reset

        _cmd="$command"
        _cmd="$(echo $_cmd | sed "s#{file}#$file#g")"
        _cmd="$(echo $_cmd | sed "s#{base_name}#$base_name#g")"
        _cmd="$(echo $_cmd | sed "s#{dir_name}#$dir_name#g")"
        _cmd="$(echo $_cmd | sed "s#{base_prefix}#$base_prefix#g")"

        eval $_cmd
        _status="$?"

        if [ "$_status" == "0" ]; then
            success "Success!" >&1
        else
            if [[ "$bell_on_error" ]]; then
                error "\a" >&2
            fi
            error "Failed!" >&2
        fi
    fi
done

color reset
