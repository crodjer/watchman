#/usr/bin/env sh

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
            if [[ -z "$inotify_exclude" ]]; then
                inotify_exclude="$OPTARG"
            else
                inotify_exclude="($OPTARG)|($inotify_exclude)"
            fi
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
inotify_flags="$inotify_bool_flags -m --timefmt %s --format %T-%e-%w%f"
inotify_cmd="inotifywait $inotify_flags $inotify_events $inotify_exclude $files"

if [[ "$verbose" ]]; then
    stderr "Will watch: $files"
fi

# Make stderr yellow
color yellow
$inotify_cmd | while read key; do

    timestamp=$(echo $key | cut -d '-' -f 1)
    events=$(echo $key | cut -d '-' -f 2)
    file_name=$(echo $key | cut -d '-' -f 3-)

    if [ "$_prev_key" != "$key" ]; then
        # This helps us prevent firing the command multiple times, because
        # inotify raises multiple events
        _prev_key="$key"

        color yellow

        if [[ "$verbose" ]]; then
            stderr "[$(date)] $file_name: $events"
        fi

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

            if [[ "$bell_on_error" ]]; then
                error "\a" >&2
            fi
            error "Failed!" >&2
        fi
    fi
done

color reset
