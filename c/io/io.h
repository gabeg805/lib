/* Header guard */
#ifndef PERSONAL_LIB_IO_H
#define PERSONAL_LIB_IO_H

/* Inlcudes */
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

/* Globals */
extern bool QUIET;
extern bool VERBOSE;
extern bool DEBUG;

/* Types */
typedef enum {
    PINFO,
    PWARN,
    PERR,
    PLOG,
    PDEBUG
} print_t;

/* Public functions */
int printinfo(const char *format, ...);
int printwarn(const char *format, ...);
int printerr(char *program, const char *format, ...);
int printlog(char *file, const char *format, ...);
int printdebug(char *file, print_t type, const char *format, ...);

#endif /* PERSONAL_LIB_IO_H */
