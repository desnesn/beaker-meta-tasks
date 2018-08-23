#!/bin/bash

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

. /usr/share/beakerlib/beakerlib.sh

rlJournalStart

    rlPhaseStartTest
        sleep 600
        rlFail "should be killed before reaching this line"
    rlPhaseEnd

rlJournalEnd

rlJournalPrintText
