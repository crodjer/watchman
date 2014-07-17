#/usr/bin/env sh

_HELP=`cat <<EOF
Usage: watchman <file-patterns> -- <command>

file-patterns
-------------
Space separated file names/patterns which are to be watched by 'watchman'. This
can also be a directory, in which case, all the files will be watched for
changes.

command
-------
The command which is to be executed when a change is triggered. Since, watchman
can watch multiple files, a you can use {file} as a placeholder in your
command. It will automatically be replaced by the file which was modified.

Note:
In case you only have a single file as watch target, the delimter '--' can be
skipped.
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
        color green
        echo "$_HELP"
    else
        color yellow
        printf "\n\n$_HELP\n" >&2
    fi

    color reset
}

error () {
    color red
    printf "$@" 1>&2
    color reset
}

success () {
    color green
    printf "$@"
    color reset
}

args="$@"

if [[ "$args" == "" ]]; then
    show_help stdin
    exit 0
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
    error "No files provided to watch on."
    show_help
    exit 1
fi

if [[ "$command" == "" ]]; then
    error "Command should not be blank."
    show_help
    exit 1
fi

# Make stderr yellow
color yellow

events="modify,attrib,moved_to,create,delete"
inotifywait -mre $events --format '%w%f' $files | while read file_name; do
    _current_key="$(date +"%s")-$file_name"

    if [ "$_prev_key" != "$_current_key" ]; then
        # This helps us prevent firing the command multiple times, because
        # inotify raises multiple events
        _prev_key="$_current_key"

        color red
        _cmd="$(echo $command | sed "s#{file}#$file_name#g")"
        output=$(bash -c "$_cmd")
        color reset

        if [ "$output" != "" ]; then
            output="$output\n"
        fi

        if [ "$?" == "0" ]; then
            success "$output"
        else
            error "$output"
        fi
    fi
done

color reset
