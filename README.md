Watchman
========

NAME
----
watchman - execute a command when something changes

SYNOPSIS
--------

    watchman [OPTIONS] <FILE PATTERNS> -- <COMMAND>
    watchman [OPTIONS] <FILE NAME> <COMMAND>

DESCRIPTION
-----------

**Execute a command as things change in file(s)/directory(s).**

I have always wanted a `watch` tool which instead of being based on time (the
watch command) will be based on space (files). That is what watch `watchman` is.

It uses [inotify tools](https://github.com/rvoicilas/inotify-tools) to provide
that functionality. Watchman just listens to what `inotifywait` (from
intoify-tools package of your distribution) says and executes commands.

This basically provides a continuous execution system, while not having to set
up a elaborate project configuration (say, when what you are working on is just
a tiny script).

In case of bigger projects, you could also have a test suit which needs to be
run when you edit a project file.

Watchman also takes special care of not cluttering the `STDOUT`. Only your
actual command can write to `STDOUT`.

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

INSTALL
-------

 - Checkout `cd` to the the source code.
 - To install, run `make install`.
 - To uninstall, run `make uninstall`.
 - If you are modifying watchman and want those changes to reflect automatically
   on next execution, then run: `make develop`. This just symlinks the script to
   the project directory.
 - Available parameters:

    - **PREFIX**: Location of installation. (default: `/usr/local/bin`)
    - **EXECUTABLE**: Name of the executable file. (default: `watchman`)

EXAMPLES
-------

 - Watch a shell script and execute it on change.

        watchman sample.sh ./sample.sh

 - Watch on the Haskell project under the current directory recursively and run
   `Main.hs` when anything is changed in it.

        watchman -r . -- runhaskell Main.hs

 - Watch on a few Python scripts and execute a script which it changes. This
   uses the placeholder {file} to fill in the correct name. Give more verbose
   output since multiple files are being watched.

        watchman -v scripts/**/*.py -- python {file}

WHY THIS PROJECT?
-----------------

 - I badly needed a utility like this.
 - I wanted to get my hands dirty with a proper bash based project and
   Makefiles.

TODO
----

 - Support for long running processes. Eg. Reboot a web server. This will be
   useful in cases where corresponding server tool does not provide an option to
   auto-reload.
 - Cycle through output colors in subsequent runs.
 - Real MAN pages, instead of MAN like README doc.
