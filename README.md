Watchman
========

NAME
----
watchman - lets you spend more time on your favourite editor

SYNOPSIS
--------

    watchman [OPTIONS] <FILE PATTERNS> -- <COMMAND>
    watchman [OPTIONS] <FILE NAME> <COMMAND>

DESCRIPTION
-----------

**Execute a command as things change in file(s)/directory(s).**

I have always wanted a `watch` tool. Not that time based watch command, which of
course is very useful, but not in all the cases. A lot of times you want to
watch on space (files) too.

Basically, when a file changes, I want to execute a command. There is a great
tool ([inotify](https://github.com/rvoicilas/inotify-tools) that will tell you
about changes, but nothing more. So, watchman just listens to what `inotifywait`
says and executes commands.

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

EXAMPLES
-------

 - Watch a shell script and execute it on change.

        watchman sample.sh ./sample.sh

 - Watch on the Haskell project under the current directory and run `Main.hs`
   when anything is changed in it.

        watchman . -- runhaskell Main.hs

 - Watch on a few Python scripts and execute a script which it changes. This
   uses the placeholder {file} to fill in the correct name.

        watchman scripts/*.py scripts/**/*.py -- python {file}

TODO
----

 - Makefile.
 - Cycle through output colors in subsequent runs.
 - Support for long running processes. Eg. Reboot a web server. This will be
   useful in cases where corresponding server tool does not provide an option to
   auto-reload.
