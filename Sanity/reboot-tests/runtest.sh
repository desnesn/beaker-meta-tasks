#!/bin/bash

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

. /usr/bin/rhts-environment.sh || exit 1

if [ "$REBOOTCOUNT" -eq 0 ] ; then
    rhts-reboot
elif [ "$REBOOTCOUNT" -eq 1 ] ; then
    report_result $TEST PASS 0
else
    report_result $TEST/nonsensical-rebootcount-value FAIL 0
fi
