#/usr/bin/env sh

PROGRAM_NAME=$(basename $0)

_HELP_VERBOSE=`cat <<EOF
Usage:

    $PROGRAM_NAME [OPTIONS] <FILE PATTERNS> -- <COMMAND>
    $PROGRAM_NAME [OPTIONS] <FILE NAME> <COMMAND>

OPTIONS
-------

 -h Show detailed help


FILE PATTERNS
-------------
Space separated file names/patterns which are to be watched by 'watchman'. This
can also be a directory, in which case, all the files will be watched for
changes.

COMMAND
-------
The command which is to be executed when a change is triggered. Since, watchman
can watch multiple files, a you can use {file} as a placeholder in your
command. It will automatically be replaced by the file which was modified.

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

color () {
    case $1 in
        red)
            _col='\e[0;31m'
            ;;
        yellow)
            _col='\e[0;33m'
            ;;
        green)
            _col='\e[0;32m'
            ;;
        *)
            _col='\e[0m'
    esac

    printf $_col
}

show_help () {
    if [[ "$1" == "stdin" ]]; then
        echo "$_HELP_VERBOSE"
    else
        color yellow
        printf "\n\n$_HELP\n" >&2
    fi

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

while getopts :h opt; do
  case $opt in
      h)
          show_help stdin
          exit 0
          ;;
      \?)
          error "Invalid option: -$OPTARG" >&2
          exit 1
  esac

  shift $(($OPTIND-1))
done

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

# Make stderr yellow
color yellow

inotify_events="modify,attrib,moved_to,create,delete"
inotify_flags="--timefmt %s --format %T-%e-%w%f"

inotifywait -mre $inotify_events $inotify_flags $files | while read key; do

    timestamp=$(echo $key | cut -d '-' -f 1)
    events=$(echo $key | cut -d '-' -f 2)
    file_name=$(echo $key | cut -d '-' -f 3-)

    if [ "$_prev_key" != "$key" ]; then
        # This helps us prevent firing the command multiple times, because
        # inotify raises multiple events
        _prev_key="$key"

        color yellow

        _cmd="$(echo $command | sed "s#{file}#$file_name#g")"
        output=$(bash -c "$_cmd")
        _status="$?"

        color reset

        if [ "$_status" == "0" ]; then
            if [ "$output" != "" ]; then
                success "$output"
            fi
            success "Success!" >&2
        else
            if [ "$output" != "" ]; then
                error "$output"
            fi
            error "Failed!" >&2
        fi
    fi
done

color reset
