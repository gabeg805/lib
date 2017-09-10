# LIBRARY

## What is it?

Library of utilities for a variety of languages.

## Installation

This will vary from project to project.

### Bash

For a Bash script, you would source the script to gain access to the
functions. Using the utility script as an example:
```
. /path/to/library/bash/util.sh
```

### C

For a C program, you would need to *#include* the library header file in your
program's source file. Using the *io* library as an example:
```
#include "io/io.h"
```

Then, depending on your compilation process, if you output object files first,
you would need to add the directory where the library header file exists in the
*gcc* command line. For instance:
```
$ gcc -g -Wall -I</path/to/library/c> -o <object-file.o> -c <source-file.c>
```

Finally, when you compile your program, add the library source file to the
command line.
```
$ gcc -g -Wall -o <program> <object-file(s).o> </path/to/library/c/io/io.c>
```
