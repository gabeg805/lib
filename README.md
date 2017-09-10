# LIBRARY

## What is it?

Library of utilities for a variety of languages.

## Installation

This will vary from project to project.

For a Bash script, you would source the utility script by executing:
```
. /path/to/library/bash/util.sh
```

For a C program, you would need to *#include* the library header file in your
program's source file. Using the *io* library as an example:
```
#include "io/io.h"
```

Then, depending on your compilation process, if you output object files first,
you would need to add the directory where the library header file exists in the
*gcc* command line. For instance:
```
$ gcc -g -Wall -I</path/to/library/c>
```

Finally, when you compile your program, add the library source file to the
command line.
```
$ gcc -g -Wall -o <program> <object-files.o> </path/to/library/c/io/io.c>
```
