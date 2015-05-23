#!/usr/bin/env bash

## Utility to call a list of scripts from akutils and brief uses

## Get script location

scriptdir="$( cd "$( dirname "$0" )" && pwd )"

less $scriptdir/docs/command_list.txt

exit 0
