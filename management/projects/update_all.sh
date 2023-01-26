#!/bin/bash

# How to call the update scropt for two orgs

# Get to the direcory where scripts are
SOURCE="${BASH_SOURCE[0]}"
LOCATION=`realpath "${BASH_SOURCE[0]}" | sed 's/update_all.sh//g'`
CURRENT=`pwd`
cd "${LOCATION}"

# Run the commands
./update_org.sh enarx
./update_org.sh profianinc assets,enarxsign,operations,iqt-demo,build-steward

# Clean temp files and return where we were
rm *.json
cd "${CURRENT}"
