#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/beaker-in-a-box/Sanity/beaker-in-a-box
#   Description: Check beaker-in-a-box works well
#   Author: Hui Wang <huiwang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="ansible"

rlJournalStart
    rlPhaseStartSetup
	rlServiceStart libvirtd
	rlAssert0 "libvirtd started" $?
	if ! rlCheckRpm $PACKAGE; then
                dnf install $PACKAGE -y
                rlAssertRpm $PACKAGE
        fi
	rlRun "ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''" 0 "Generated ssh rsa keys"
	rlRun "git clone http://gerrit.beaker-project.org/beaker-in-a-box" 0 "Cloned beaker-in-a-box code from repo"
	rlRun "cd beaker-in-a-box" 0 "Enter beaker-in-a-box directory"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "ansible-playbook setup_beaker.yml" 0 "Run ansible-playbook"
        rlAssert0 "beaker-in-a-box ansible-playbook works well" $?
	rlRun "curl -I  http://beaker-server-lc.beaker/bkr/ | grep '200 OK'" 0 "Verifying the server installation"
	rlAssert0 "http://beaker-server-lc.beaker/bkr/ works well" $?
    rlPhaseEnd
