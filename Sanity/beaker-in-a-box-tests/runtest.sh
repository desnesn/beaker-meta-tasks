#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /distribution/beaker/beaker-in-a-box
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


rlJournalStart
    rlPhaseStartSetup
        CWD=$(pwd)
        REFSPEC=${GERRIT_REFSPEC:-master}

        for PACKAGE in ansible git libvirt libvirt-daemon-kvm
        do
            if ! rlCheckRpm $PACKAGE; then
                dnf install $PACKAGE -y
                rlAssertRpm $PACKAGE
            fi
        done
        rlServiceStart libvirtd
        rlRun "adduser -G wheel testuser" 0 "Create a test user"
        rlRun "sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers" 0 "Allow NOPASSWD sudo privileges"
        rlRun "sudo -n -H -E -u testuser ${CWD}/setup.sh" 0 "Generated ssh rsa keys"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "sudo -n -H -E -u testuser ${CWD}/runplaybook.sh" 0 "Run testing of ansible-playbook"
    rlPhaseEnd
rlJournalEnd
