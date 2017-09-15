# ******************************************************************************
# 
# Name:    util.py
# Author:  Gabriel Gonzalez
# Email:   gabeg@bu.edu
# License: The MIT License (MIT)
# 
# Syntax: import personal.util
# 
# Description: Personal utility library.
# 
# Notes: None.
# 
# ******************************************************************************

# Imports
import logging

# ******************************************************************************
def log_file_handler(filename, fmt=None, level=None):
    '''
    Handle log file configuration.
    '''

    if (fmt is None):
        fmt = '[%(asctime)s] %(name)s: %(levelname)s: %(message)s'
    if (level is None):
        level = logging.INFO

    handler = logging.FileHandler(filename)
    handler.setLevel(level)
    formatter = logging.Formatter(fmt)
    handler.setFormatter(formatter)

    return handler
