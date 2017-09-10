/* Includes */
#include "io.h"
#include <stdio.h>
#include <string.h>

/* ************************************************************************** */
/* Print information */
int printinfo(const char *format, ...)
{
    /* Prepend info indicator to format */
    size_t len = strlen(format)+4;
    char   infofmt[len];
    snprintf(infofmt, len, ":: %s", format);

    /* Print */
    va_list args;
    va_start(args, format);
    int status = vprintf(infofmt, args);
    va_end(args);

    return status;
}

/* ************************************************************************** */
/* Print warnings */
int printwarn(const char *format, ...)
{
    /* Prepend warning indicator to format */
    size_t len = strlen(format)+4;
    char   warnfmt[len];
    snprintf(warnfmt, len, "-- %s", format);

    /* Print */
    va_list args;
    va_start(args, format);
    int status = vprintf(warnfmt, args);
    va_end(args);

    return status;
}

/* ************************************************************************** */
/* Print errors */
/* Not sure if this macro method will work, but can test */
int printerr(char *program, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int status;

    /* Append error indicator to format and print */
    if (program == NULL)
        status = vprintf(format, args);
    else {
        size_t len = strlen(format)+strlen(program)+3;
        char errfmt[len];
        snprintf(errfmt, len, "%s: %s", program, format);
        status = vfprintf(stderr, errfmt, args);
    }

    va_end(args);

    return status;
}

/* ************************************************************************** */
/* Log output */
int printlog(char *file, const char *format, ...)
{
    /* Get current time */
    time_t timep = time(NULL);
    char   date[26];
    strftime(date, sizeof(date), "%F %T %z", localtime(&timep));

    /* Prepend date to format */
    size_t len = strlen(format)+sizeof(date)+4;
    char   logfmt[len];
    snprintf(logfmt, len, "[%s] %s", date, format);

    /* Print */
    va_list args;
    va_start(args, format);
    int status;
    if (file == NULL)
        ;
    else {
        if (access(file, F_OK) && !access(file, W_OK))
            printerr("Unable to log output: ", "Missing write permisions.");
        else {
            FILE *handle = fopen(file, "a+");
            status = vfprintf(handle, logfmt, args);
            fclose(handle);
        }
    }
    va_end(args);

    return status;
}

/* ************************************************************************** */
/* Print debug output */
int printdebug(char *file, print_t type, const char *format, ...)
{
    int     status;
    va_list args;
    va_start(args, format);

    switch (type) {
    case PINFO:
        printinfo(format, args);
        break;
    case PWARN:
        printwarn(format, args);
        break;
    case PERR:
        printerr("Debug", format, args);
        break;
    default:
        break;
    }

    status = printlog(file, format, args);
    va_end(args);

    return status;
}
